import Foundation
import AppKit
import IMEmoryCore

// 冷启动锚定:在不改变当前状态的前提下确定初始中/英模式。
// 若状态未知,则发送两次 M2 切换(净零效果),并在两次之间读取 HUD。
// 需要有聚焦的文本框才能生效,否则将在首次切换时懒加载锚定。
func anchor(_ tracker: StateTracker) {
    if tracker.sampleOnce() != nil { return }
    Switcher.postShiftToggle(); usleep(240_000); _ = tracker.sampleOnce()
    Switcher.postShiftToggle(); usleep(240_000); _ = tracker.sampleOnce()
}

let store = AppMemoryStore.defaultStore()
let tracker = StateTracker()
let controller = AutoSwitchController(tracker: tracker, store: store)
controller.onEvent = { print("\(Date()) \($0)") }

print("IMEmory daemon 启动。冷启动锚定中(请确保有输入框聚焦)…")
anchor(tracker)
print("当前态 = \(tracker.current?.rawValue ?? "未知(等首次切换锚定)")")
controller.start()
print("运行中:切换 App 会自动记忆/恢复中英。Ctrl-C 退出。")

// NSWorkspace 通知需要在具有 App 上下文的主 RunLoop 中运行。
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // 后台常驻,不显示 Dock 图标
app.run()
