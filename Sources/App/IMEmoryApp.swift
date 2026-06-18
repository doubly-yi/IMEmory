import SwiftUI
import AppKit

@main
struct IMEmoryApp: App {
    @StateObject private var state: AppState
    // 菜单栏图标显隐:用 @AppStorage 而非 @Published,避免 MenuBarExtra 写回造成的刷新死循环。
    @AppStorage("showMenuBarIcon") private var iconVisible = true

    init() {
        let controller = AppController()
        controller.start()
        let appState = AppState(controller: controller)
        appState.startBridging()
        _state = StateObject(wrappedValue: appState)

        // 首次启动(还没有任何校准)→ 自动打开设置并直达校准页引导用户。
        if controller.hasNoCalibration {
            appState.settingsTab = .calibration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $iconVisible) {
            MenuContent().environmentObject(state)
        } label: {
            Text(state.glyph)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView().environmentObject(state)
        }
    }
}
