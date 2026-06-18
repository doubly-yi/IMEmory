import Foundation
import AppKit

/// 将 AppMonitor、StateTracker、AppMemoryStore 和 SwitchDecision 串联起来,
/// 实现"离开时记忆、进入时恢复"的核心行为。
public final class AutoSwitchController {
    private let monitor: AppMonitor
    private let tracker: StateTracker
    private let store: AppMemoryStore
    private var currentApp: String?
    private var restoreGeneration = 0          // 自增以取消"过时"的待恢复(切到别的 App 时)
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
        // 用户在同一应用内切换时,实时更新该应用的记录。
        tracker.onChange = { [weak self] mode in
            guard let self, self.switchingEnabled, let app = self.currentApp else { return }
            self.store.record(bundleId: app, mode: mode)
            self.onEvent?("记录 \(app) = \(mode.rawValue)")
        }
        tracker.start()

        monitor.onActivate = { [weak self] bundleId, name in
            self?.handleActivate(bundleId: bundleId, name: name)
        }
        monitor.start()

        // 用当前前台应用初始化 currentApp。
        if let f = AppMonitor.frontmost() { currentApp = f.bundleId }
    }

    public func stop() { monitor.stop(); tracker.stop() }

    private func handleActivate(bundleId: String, name: String) {
        guard switchingEnabled else { currentApp = bundleId; return }
        let outcome = SwitchDecision.onActivate(
            newApp: bundleId,
            currentMode: tracker.current,
            savedModeForNewApp: store.mode(for: bundleId),
            newAppExcluded: store.isExcluded(bundleId))

        // 不再"离开时记录":记录只由 tracker.onChange(真正观测到切换)负责,
        // 避免把上一个 App 残留的状态错记给当前 App。
        currentApp = bundleId

        // 每次激活都自增代号,自动取消上一个 App 还没完成的待恢复/待学习。
        restoreGeneration += 1
        if let target = outcome.switchTo {
            // 取目标 App 的 pid,用于提示 Electron 类 App 立刻启用辅助功能树。
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            scheduleRestore(target: target, app: name, pid: pid, generation: restoreGeneration)
        } else if store.mode(for: bundleId) == nil, !store.isExcluded(bundleId), bundleId != ownBundleID {
            // 尚无记录的 App:等它真正有文本焦点后,把当前全局中/英学习为它的初始状态。
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            scheduleLearn(app: name, bundleId: bundleId, pid: pid, generation: restoreGeneration)
        }
    }

    /// 进入"尚无记录"的 App:等它真正获得文本焦点后,把当前全局中/英记为它的初始状态(学习一次)。
    /// 文本焦点闸门确保只给真正能输入的上下文记录,不给设置/文件树等无输入框上下文误记
    /// ——那正是当年移除"离开即记录"的根因。
    private func scheduleLearn(app: String, bundleId: String, pid: pid_t?, generation: Int) {
        onEvent?("进入 \(app)(无记录)→ 待文本焦点后学习当前状态")
        if let pid { FocusProbe.enableAccessibility(pid: pid) }
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(60.0)
            while Date() < deadline {
                if self.restoreGeneration != generation { return }   // 切走了,静默取消
                if FocusProbe.hasTextFocus() {
                    // 等待期间用户可能已手动切换并被 onChange 记录;仅在仍无记录时才学习,避免覆盖。
                    if self.store.mode(for: bundleId) == nil, let mode = self.tracker.current {
                        self.store.record(bundleId: bundleId, mode: mode)
                        self.onEvent?("学习 \(app) = \(mode.rawValue)")
                    }
                    return
                }
                usleep(200_000)
            }
        }
    }

    /// 等到目标 App 真正有文本焦点了再合成 Shift 恢复;若中途切到别的 App 则放弃。
    /// 这样解决"切过去时还没点进输入框 → 恢复失败、状态停在上一个 App"的竞态。
    private func scheduleRestore(target: IMEMode, app: String, pid: pid_t?, generation: Int) {
        onEvent?("进入 \(app) → 待文本焦点后恢复为 \(target.rawValue)")
        // 提前唤醒 Electron(如 Claude)的辅助功能,否则焦点要等树懒加载好几秒。
        if let pid { FocusProbe.enableAccessibility(pid: pid) }
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            // 一直等到出现文本焦点;切到别的 App 则取消。最多等 60 秒(安全上限)。
            let deadline = Date().addingTimeInterval(60.0)
            var lastInfo = ""
            while Date() < deadline {
                if self.restoreGeneration != generation { return }   // 切走了,静默取消
                if FocusProbe.hasTextFocus() {
                    let ok = self.tracker.setMode(target)
                    self.onEvent?(ok ? "✓ 已恢复 \(app) 为 \(target.rawValue)"
                                     : "✗ 恢复 \(app) 失败(有焦点但没读到小窗)")
                    return
                }
                // 诊断:聚焦元素变化时记一条,帮排查为什么没被判为可输入。
                let info = FocusProbe.focusInfo()
                if info != lastInfo { lastInfo = info; self.onEvent?("等 \(app) 文本焦点… \(info)") }
                usleep(200_000)
            }
            self.onEvent?("✗ 恢复 \(app) 放弃(60 秒内一直没文本焦点)")
        }
    }
}
