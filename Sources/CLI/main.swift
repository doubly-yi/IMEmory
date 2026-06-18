import Foundation
import CoreGraphics
import ImageIO
import IMEmoryCore

func loadImage(_ path: String) -> CGImage? {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else { return nil }
    return i
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "resolve":
    if let r = IMEResolver.resolve() {
        print("IME=\(r.def.displayName) key=\(r.def.key) pid=\(r.pid) appearance=\(Appearance.current().rawValue)")
    } else {
        print("当前不是已知中文输入法,或进程未找到。id=\(IMEResolver.currentInputSourceID())")
    }

case "locate":
    guard let r = IMEResolver.resolve() else { print("当前不是已知输入法或进程未找到"); break }
    if let w = HUDLocator.findOnScreen(pid: r.pid, def: r.def) { print("HUD window = \(w)") }
    else { print("当前无 HUD 在屏(切一次中英再试)") }

case "calibrate":
    // ./imemory-cli calibrate <zh.png> <en.png>  — 为当前输入法+外观模式建立模板
    guard args.count >= 3, let zhImg = loadImage(args[1]), let enImg = loadImage(args[2]),
          let r = IMEResolver.resolve() else { print("用法: calibrate <zh.png> <en.png>"); break }
    let store = TemplateStore.defaultStore()
    try store.save(zh: Fingerprint.signature(zhImg), en: Fingerprint.signature(enImg),
                   for: r.def, appearance: Appearance.current())
    print("✅ 已为 \(r.def.displayName)/\(Appearance.current().rawValue) 建模板")

case "classify-file":
    // ./imemory-cli classify-file <png>  — 使用当前输入法模板对一张图进行分类
    guard args.count >= 2, let img = loadImage(args[1]), let r = IMEResolver.resolve(),
          let t = TemplateStore.defaultStore().load(for: r.def, appearance: Appearance.current())
    else { print("需先 calibrate"); break }
    print(Classifier(zh: t.zh, en: t.en).classify(img))

case "track":
    let tracker = StateTracker()
    tracker.onChange = { print("\(Date()) -> 【\($0.rawValue)】") }
    tracker.start()
    print("tracking… 按 Shift 切中英,Ctrl-C 退出")
    RunLoop.main.run()

case "set":
    // ./imemory-cli set <zh|en>  — 切换到指定模式
    guard args.count >= 2, let mode = (args[1] == "zh" ? IMEMode.zh : args[1] == "en" ? .en : nil)
    else { print("用法: set zh|en"); break }
    let tracker = StateTracker()
    _ = tracker.sampleOnce()                 // 锚定当前状态
    let ok = tracker.setMode(mode)
    print(ok ? "✅ 已切到 \(mode.rawValue)" : "✗ 未能切到 \(mode.rawValue)(当前=\(tracker.current?.rawValue ?? "未知"))")

case "shift":
    Switcher.postShiftToggle(); print("已发送 M2 合成 Shift")

default:
    print("""
    用法: imemory-cli <命令>
      resolve                 显示当前输入法/pid/外观
      locate                  显示当前 HUD 窗口号
      calibrate <zh> <en>     用两张 HUD 图为当前输入法+外观建模板
      classify-file <png>     用当前模板分类一张图
      track                   持续打印中/英变化
      set <zh|en>             切到目标态(读回校验)
      shift                   发一次 M2 合成 Shift
    """)
}
