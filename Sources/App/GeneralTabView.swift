import SwiftUI

/// Tab3:开机自启、菜单栏图标开关、权限状态与跳转。
struct GeneralTabView: View {
    @EnvironmentObject var state: AppState
    // 与 IMEmoryApp 共用同一 UserDefaults 键,二者自动同步。
    @AppStorage("showMenuBarIcon") private var iconVisible = true
    @State private var screenOK = false
    @State private var axOK = false
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("启动") {
                Toggle("开机自启", isOn: Binding(
                    get: { launchAtLogin },
                    set: { LoginItem.setEnabled($0); launchAtLogin = LoginItem.isEnabled }))
            }
            Section("菜单栏") {
                Toggle("显示菜单栏图标", isOn: $iconVisible)
            }
            Section("权限") {
                permissionRow(title: "屏幕录制(读取中/英 HUD)", ok: screenOK) {
                    PermissionProbe.openScreenRecordingSettings()
                }
                permissionRow(title: "辅助功能(合成 Shift 切换)", ok: axOK) {
                    PermissionProbe.openAccessibilitySettings()
                }
                HStack {
                    Spacer()
                    Button("重新检测") { refresh() }
                }
            }
        }
        .formStyle(.grouped)   // 系统设置风格的分组卡片:三组一目了然,且内容顶部对齐
        .onAppear(perform: refresh)
    }

    private func permissionRow(title: String, ok: Bool, open: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(ok ? "✅ 已授权" : "❌ 未授权").foregroundStyle(ok ? .green : .red)
            Button("打开设置", action: open)
        }
    }

    private func refresh() {
        screenOK = PermissionProbe.hasScreenRecording()
        axOK = PermissionProbe.hasAccessibility()
        launchAtLogin = LoginItem.isEnabled
    }
}
