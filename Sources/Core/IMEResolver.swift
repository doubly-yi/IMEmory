import AppKit
import Carbon
import Foundation

public struct ResolvedIME {
    public let sourceID: String     // 模板 key,如 "com.sogou.inputmethod.sogou.pinyin"
    public let displayName: String  // "搜狗拼音"
    public let pid: Int
}

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

    /// 解析当前活跃输入法:输入源 ID → 前缀匹配运行 app 拿 pid → 本地化名。
    /// 非可校准输入模式 / 找不到对应运行 app 时返回 nil。
    public static func resolve() -> ResolvedIME? {
        let sid = currentInputSourceID()
        guard !sid.isEmpty else { return nil }
        let apps: [(bundleID: String, pid: Int, name: String)] =
            NSWorkspace.shared.runningApplications.compactMap { app in
                guard let bid = app.bundleIdentifier else { return nil }
                return (bid, Int(app.processIdentifier), app.localizedName ?? bid)
            }
        guard let m = matchApp(sourceID: sid, apps: apps) else { return nil }
        return ResolvedIME(sourceID: sid, displayName: currentLocalizedName() ?? m.name, pid: m.pid)
    }

    /// 纯函数:在运行 app 列表里找 bundleId 是 sourceID 前缀且最长的那个。便于单测。
    public static func matchApp(sourceID: String,
                                apps: [(bundleID: String, pid: Int, name: String)]) -> (pid: Int, name: String)? {
        let hit = apps.filter { !$0.bundleID.isEmpty && sourceID.hasPrefix($0.bundleID) }
        guard let best = hit.max(by: { $0.bundleID.count < $1.bundleID.count }) else { return nil }
        return (best.pid, best.name)
    }

    /// 当前输入源的本地化名(如"搜狗拼音")。TIS 须主线程调用,故同 currentInputSourceID 处理。
    public static func currentLocalizedName() -> String? {
        if Thread.isMainThread { return readCurrentLocalizedName() }
        return DispatchQueue.main.sync { readCurrentLocalizedName() }
    }
    private static func readCurrentLocalizedName() -> String? {
        guard let s = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let p = TISGetInputSourceProperty(s, kTISPropertyLocalizedName) else { return nil }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }
}
