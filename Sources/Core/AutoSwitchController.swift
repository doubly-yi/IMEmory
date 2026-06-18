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
    private var overlayTimer: Timer?   // 仅在覆盖层(Spotlight)打开期间运行的短期轮询(察觉其关闭)
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

        // 普通 App 切换:NSWorkspace 事件 → 处理上下文(observe 由 handleContext 统一做)。
        monitor.onActivate = { [weak self] bundleId, name in
            guard let self else { return }
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.processIdentifier
            self.handleContext(bundleId: bundleId, name: name, pid: pid)
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
        // 自己前台(点菜单/开设置):只记下当前是自己,绝不对自己挂监听/设增强无障碍(会让菜单点击无反应)。
        if bundleId == ownBundleID { currentApp = bundleId; pending = nil; stopOverlayWatch(); return }
        guard bundleId != currentApp else { return }
        currentApp = bundleId
        pending = nil
        pendingPid = pid
        // 覆盖层(如 Spotlight):焦点属主 ≠ 系统前台 App。它不触发激活、关闭也不发焦点事件,
        // 故只对覆盖层用短期轮询察觉其关闭;对真实 App 才重挂 AXObserver(其失焦事件能察觉进入覆盖层)。
        let isOverlay = bundleId != NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let pid {
            if !isOverlay { focusObserver.observe(pid: pid) }
            FocusProbe.enableAccessibility(pid: pid)
        }
        if isOverlay { startOverlayWatch() } else { stopOverlayWatch() }
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
        // 自己在前台时,绝不查自己的 AX(廉价的 NSWorkspace 判断,不触发 AX 自查)。
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ownBundleID { return }
        if let owner = FocusProbe.focusedApp(), owner.bundleID != currentApp {
            handleContext(bundleId: owner.bundleID, name: owner.name, pid: owner.pid)
        } else {
            tryCompletePending()
        }
    }

    /// 覆盖层(Spotlight)打开期间的短期轮询:每 ~300ms 看焦点是否离开它,离开就切到新属主并停。
    /// 仅在覆盖层存在时运行(关掉即停),正常用 App 时不轮询。
    private func startOverlayWatch() {
        guard overlayTimer == nil else { return }
        let t = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == self.ownBundleID { return }
            if let owner = FocusProbe.focusedApp(), owner.bundleID != self.currentApp {
                self.handleContext(bundleId: owner.bundleID, name: owner.name, pid: owner.pid)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        overlayTimer = t
    }

    private func stopOverlayWatch() { overlayTimer?.invalidate(); overlayTimer = nil }

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
