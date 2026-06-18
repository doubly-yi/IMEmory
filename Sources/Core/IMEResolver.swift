import Carbon
import Foundation

public struct ResolvedIME { public let def: IMEDef; public let pid: Int }

public enum IMEResolver {
    /// 当前键盘输入源的 id,例如 "com.bytedance.inputmethod.doubaoime.pinyin"。
    /// 注:TIS/HIToolbox 输入源 API 必须在主线程调用,否则后台线程会触发
    ///     dispatch_assert_queue 断言导致崩溃(尤其当 app 已有真实窗口时)。
    ///     StateTracker 在后台线程轮询,故这里统一把 TIS 调用切到主线程。
    public static func currentInputSourceID() -> String {
        if Thread.isMainThread { return readCurrentInputSourceID() }
        return DispatchQueue.main.sync { readCurrentInputSourceID() }
    }

    private static func readCurrentInputSourceID() -> String {
        guard let s = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }

    /// 通过 pgrep -f 返回命令行匹配 `pattern` 的第一个进程 pid。
    public static func pid(matching pattern: String) -> Int? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-f", pattern]
        let pipe = Pipe(); p.standardOutput = pipe
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .split(separator: "\n").first.flatMap { Int($0) }
    }

    /// 将当前活跃输入法解析为其定义及运行中的 pid,若不是已知输入法或进程未运行则返回 nil。
    public static func resolve() -> ResolvedIME? {
        guard let def = IMERegistry.lookup(inputSourceID: currentInputSourceID()),
              let pid = pid(matching: def.processMatch) else { return nil }
        return ResolvedIME(def: def, pid: pid)
    }
}
