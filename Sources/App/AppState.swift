import SwiftUI
import IMEmoryCore

/// 把 core 的后台状态桥接到 SwiftUI:用主线程定时器轮询 tracker.current。
/// (AutoSwitchController 已占用 tracker.onChange,故这里用轮询而非抢回调。)
final class AppState: ObservableObject {
    @Published var mode: IMEMode?
    @Published var paused: Bool = false
    @Published var imeName: String?
    @Published var settingsTab: SettingsTab = .records
    // 注:菜单栏图标显隐改用 @AppStorage("showMenuBarIcon"),不放在这里。
    //     若用 @Published 绑定 MenuBarExtra(isInserted:),菜单栏每次刷新会写回该属性,
    //     @Published 无条件 republish → 触发刷新 → 再写回,形成死循环把主线程拖垮。

    let controller: AppController
    private var timer: Timer?

    init(controller: AppController) {
        self.controller = controller
        self.mode = controller.tracker.current
        self.paused = controller.isPaused
        self.imeName = controller.tracker.currentIMEName
    }

    /// 每 0.2s 把后台 tracker 的当前态搬到主线程。
    func startBridging() {
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let cur = self.controller.tracker.current
            if cur != self.mode { self.mode = cur }
            let p = self.controller.isPaused
            if p != self.paused { self.paused = p }
            let nm = self.controller.tracker.currentIMEName
            if nm != self.imeName { self.imeName = nm }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func togglePause() {
        controller.setPaused(!controller.isPaused)
        paused = controller.isPaused
    }

    var glyph: String { ModeGlyph.symbol(for: mode) }
}
