import SwiftUI
import IMEmoryCore

/// 把 core 的状态桥接到 SwiftUI:订阅 .imemoryStateChanged 通知刷新(取代轮询)。
final class AppState: ObservableObject {
    @Published var mode: IMEMode?
    @Published var paused: Bool = false
    @Published var imeName: String?
    @Published var settingsTab: SettingsTab = .records

    let controller: AppController
    private var stateObserver: NSObjectProtocol?

    init(controller: AppController) {
        self.controller = controller
        self.mode = controller.tracker.current
        self.paused = controller.isPaused
        self.imeName = controller.tracker.currentIMEName
    }

    /// 订阅状态变化通知,在主线程刷新 @Published(菜单图标随之更新)。
    func startBridging() {
        stateObserver = NotificationCenter.default.addObserver(
            forName: .imemoryStateChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.mode = self.controller.tracker.current
            self.imeName = self.controller.tracker.currentIMEName
        }
    }

    deinit { if let o = stateObserver { NotificationCenter.default.removeObserver(o) } }

    func togglePause() {
        controller.setPaused(!controller.isPaused)
        paused = controller.isPaused
    }

    var glyph: String { ModeGlyph.symbol(for: mode) }
}
