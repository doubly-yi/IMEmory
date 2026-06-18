import Foundation
import AppKit

/// 将 AppMonitor、StateTracker、AppMemoryStore 和 SwitchDecision 串联起来,
/// 实现"离开时记忆、进入时恢复"的核心行为。
public final class AutoSwitchController {
    private let monitor: AppMonitor
    private let tracker: StateTracker
    private let store: AppMemoryStore
    private var currentApp: String?
    private let focusObserver = FocusObserver()
    private enum Pending { case restore(IMEMode), learn }
    private var pending: Pending?
    private var pendingPid: pid_t?
    public var onEvent: ((String) -> Void)?   // 可读日志行,供 daemon 使用
    /// 暂停开关:为 false 时不自动切换、不在切换应用时写记忆,但 tracker 继续采样(图标保持实时)。
    public var switchingEnabled = true
    /// 本 App 自身的 bundleId:不对自己学习/记录(否则打开设置页就会把自己记下并在下次打开时切换)。
    public var ownBundleID: String?

    public init(monitor: AppMonitor = AppMonitor(),
                tracker: StateTracker = StateTracker(),
                store: AppMemoryStore = .defaultStore()) {
        self.monitor = monitor
        self.tracker = tracker
        self.store = store
    }

    public func start() {
        // 观测到切换时记录,归属到"当前键盘焦点所属 App"(Spotlight 等覆盖层正确归属)。
        tracker.onChange = { [weak self] mode in
            guard let self, self.switchingEnabled else { return }
            guard let app = FocusProbe.focusedApp()?.bundleID ?? self.currentApp,
                  app != self.ownBundleID else { return }
            self.store.record(bundleId: app, mode: mode)
            self.onEvent?("记录 \(app) = \(mode.rawValue)")
        }
        tracker.start()

        // 普通 App 切换:NSWorkspace 事件 → 重新指向 FocusObserver + 处理上下文。
        monitor.onActivate = { [weak self] bundleId, name in
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.processIdentifier
            if let pid { self?.focusObserver.observe(pid: pid) }
            self?.handleContext(bundleId: bundleId, name: name, pid: pid)
        }
        monitor.start()

        // 焦点变化(含 Spotlight 覆盖层进出、App 内落入文本框):事件驱动。
        focusObserver.onFocusChanged = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { self.handleFocusChanged() }
        }
        if let f = AppMonitor.frontmost() {
            currentApp = f.bundleId
            if let pid = NSRunningApplication.runningApplications(withBundleIdentifier: f.bundleId).first?.processIdentifier {
                focusObserver.observe(pid: pid)
            }
        }
    }

    public func stop() { monitor.stop(); tracker.stop(); focusObserver.stop() }

    /// 进入一个新上下文(App 或覆盖层)。决定恢复/学习,并立即试着完成(可能已在输入框)。
    private func handleContext(bundleId: String, name: String, pid: pid_t?) {
        guard switchingEnabled else { currentApp = bundleId; return }
        guard bundleId != currentApp else { return }
        currentApp = bundleId
        pending = nil
        pendingPid = pid
        if let pid { FocusProbe.enableAccessibility(pid: pid) }
        let outcome = SwitchDecision.onActivate(
            newApp: bundleId,
            currentMode: tracker.current,
            savedModeForNewApp: store.mode(for: bundleId),
            newAppExcluded: store.isExcluded(bundleId))
        if let target = outcome.switchTo {
            pending = .restore(target)
            onEvent?("进入 \(name) → 待文本焦点恢复为 \(target.rawValue)")
        } else if store.mode(for: bundleId) == nil, !store.isExcluded(bundleId), bundleId != ownBundleID {
            pending = .learn
            onEvent?("进入 \(name)(无记录)→ 待文本焦点学习当前状态")
        }
        tryCompletePending()
    }

    /// 焦点变化回调:属主变了 → 当作进入新上下文;属主没变 → 推进待办(等到文本焦点)。
    private func handleFocusChanged() {
        if let owner = FocusProbe.focusedApp(), owner.bundleID != currentApp {
            handleContext(bundleId: owner.bundleID, name: owner.name, pid: owner.pid)
        } else {
            tryCompletePending()
        }
    }

    /// 若有待办且当前已是文本焦点,则完成(恢复或学习)。无文本焦点则留待下次焦点事件。
    private func tryCompletePending() {
        guard let p = pending, let app = currentApp else { return }
        guard FocusProbe.hasTextFocus(appPid: pendingPid) else { return }
        pending = nil   // 主线程先清,避免重入/重复触发
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            switch p {
            case .restore(let target):
                let ok = self.tracker.setMode(target)
                self.onEvent?(ok ? "✓ 已恢复 \(app) 为 \(target.rawValue)"
                                 : "✗ 恢复 \(app) 失败(有焦点但没读到小窗)")
            case .learn:
                if self.store.mode(for: app) == nil, let mode = self.tracker.current {
                    self.store.record(bundleId: app, mode: mode)
                    self.onEvent?("学习 \(app) = \(mode.rawValue)")
                }
            }
        }
    }
}
