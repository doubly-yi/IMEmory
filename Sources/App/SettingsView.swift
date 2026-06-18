import SwiftUI
import AppKit

/// 设置窗口:三个 Tab。选中页用 AppState.settingsTab 绑定,便于首次启动直达校准页。
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView(selection: $state.settingsTab) {
            RecordsTabView()
                .tabItem { Label("已记录", systemImage: "list.bullet") }
                .tag(SettingsTab.records)
            CalibrationTabView()
                .tabItem { Label("校准", systemImage: "scope") }
                .tag(SettingsTab.calibration)
            GeneralTabView()
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(SettingsTab.general)
        }
        .frame(width: 600, height: 460)
        .onAppear {
            // 菜单栏(accessory)app 打开设置窗口默认不激活、可能被压在后面;
            // 主动把 app 激活到最前,让设置窗口可见并接收点击。
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// 设置窗口的三个 Tab 标识。
enum SettingsTab: Hashable {
    case records, calibration, general
}
