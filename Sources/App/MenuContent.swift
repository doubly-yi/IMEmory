import SwiftUI

/// 菜单栏图标点击后的下拉菜单内容。
struct MenuContent: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        // 显示后台采样器最近一次成功识别到的输入法(不在菜单打开时实时查,
        // 否则会读到 IMEmory 自己的输入源而非用户编辑器里的输入法)。
        Text("当前:\(state.imeName ?? "未知输入法") · \(state.glyph)")
        Divider()
        Button(state.paused ? "恢复自动切换" : "暂停自动切换") { state.togglePause() }
        SettingsLink { Text("设置…") }
        Divider()
        Button("退出") { NSApplication.shared.terminate(nil) }
    }
}
