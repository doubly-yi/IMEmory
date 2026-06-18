import Foundation
import IMEmoryCore

/// 持有并驱动 core 各组件,是 GUI 的业务入口。共享同一套 store/tracker/templates。
final class AppController {
    let store: AppMemoryStore
    let templates: TemplateStore
    let tracker: StateTracker
    private let autoSwitch: AutoSwitchController

    init() {
        let store = AppMemoryStore.defaultStore()
        let templates = TemplateStore.defaultStore()
        let tracker = StateTracker(store: templates)
        self.store = store
        self.templates = templates
        self.tracker = tracker
        self.autoSwitch = AutoSwitchController(tracker: tracker, store: store)
        // 把自动切换的事件(离开存档、进入恢复、成败)接到统一日志,便于排查。
        self.autoSwitch.onEvent = { Log.sw($0) }
        // 屏幕捕获流被系统掐断(跨睡眠等)时自动重启自身恢复授权。
        tracker.onCaptureStuck = { SelfHealer.handleCaptureStuck() }
    }

    /// 冷启动锚定:不改变当前态的前提下确定初始中/英(需有输入框聚焦,否则首次切换时懒锚定)。
    func anchor() {
        if tracker.sampleOnce() != nil { return }
        Switcher.postShiftToggle(); usleep(240_000); _ = tracker.sampleOnce()
        Switcher.postShiftToggle(); usleep(240_000); _ = tracker.sampleOnce()
    }

    /// 启动:先注册监听+启动 tracker(主线程),再后台锚定(避免 usleep 卡 UI)。
    func start() {
        Log.app("启动:注册前台监听 + 后台采样")
        autoSwitch.start()
        DispatchQueue.global().async { [weak self] in
            self?.anchor()
            Log.app("冷启动锚定完成,当前态 = \(self?.tracker.current?.rawValue ?? "未知")")
        }
    }

    var isPaused: Bool { !autoSwitch.switchingEnabled }
    func setPaused(_ paused: Bool) { autoSwitch.switchingEnabled = !paused }

    /// 是否还没有任何输入法被校准过(任一外观下有模板即视为已校准)。用于首次启动引导。
    var hasNoCalibration: Bool {
        for def in IMERegistry.all {
            if templates.has(def, appearance: .light) || templates.has(def, appearance: .dark) {
                return false
            }
        }
        return true
    }
}
