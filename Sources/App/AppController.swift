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
        self.autoSwitch.ownBundleID = Bundle.main.bundleIdentifier   // 不对自己学习/切换
        // 把自动切换的事件(离开存档、进入恢复、成败)接到统一日志,便于排查。
        self.autoSwitch.onEvent = { Log.sw($0) }
        // 屏幕捕获流被系统掐断(跨睡眠等)时自动重启自身恢复授权。
        tracker.onCaptureStuck = { SelfHealer.handleCaptureStuck() }
    }

    func start() {
        Log.app("启动:注册事件监听")
        autoSwitch.start()
        DispatchQueue.global().async { [weak self] in
            self?.tracker.anchorColdStart()
            Log.app("冷启动锚定完成,当前态 = \(self?.tracker.current?.rawValue ?? "未知")")
        }
    }

    var isPaused: Bool { !autoSwitch.switchingEnabled }
    func setPaused(_ paused: Bool) { autoSwitch.switchingEnabled = !paused }

    /// 是否还没有任何输入法被校准过(任一系统输入法在任一外观下有模板即视为已校准)。
    var hasNoCalibration: Bool {
        for e in InputSourceEnumerator.selectableInputModes() {
            if templates.has(forSource: e.sourceID, appearance: .light)
                || templates.has(forSource: e.sourceID, appearance: .dark) {
                return false
            }
        }
        return true
    }
}
