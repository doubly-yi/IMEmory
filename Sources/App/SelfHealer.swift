import AppKit
import CoreGraphics
import IMEmoryCore

/// 屏幕捕获流失效时的自愈:重启 app 自身,让新进程重新拿到有效的屏幕录制授权。
///
/// 两道护栏,避免"权限真被撤销时无限重启":
///  ① 只有 `CGPreflightScreenCaptureAccess()` 仍为真(系统认为我们有权限、只是流卡死)才重启;
///     若权限确实被撤销(preflight 为假),重启也没用,改为放弃并提示用户去重新授权。
///  ② 距上次自动重启不足冷却时间(120s)则不再重启,兜底防止抖动循环。
enum SelfHealer {
    private static let cooldown: TimeInterval = 120
    /// 记录上次自动重启时刻,用于冷却判断。与 templates/日志同目录。
    private static let markerURL: URL = Log.fileURL
        .deletingLastPathComponent().appendingPathComponent("last-autorestart")

    /// 由 `StateTracker.onCaptureStuck` 调用(可能在后台线程)。
    static func handleCaptureStuck() {
        guard CGPreflightScreenCaptureAccess() else {
            Log.app("捕获失效且屏幕录制权限已不在 → 不自动重启,请到系统设置重新授权")
            return
        }
        if let last = lastRestart(), Date().timeIntervalSince(last) < cooldown {
            Log.app("捕获失效,但 \(Int(cooldown))s 内已自动重启过 → 暂不再重启(可能权限异常,请检查屏幕录制)")
            return
        }
        Log.app("检测到屏幕捕获流失效 → 自动重启自身以恢复授权")
        stampRestart()
        relaunch()
    }

    private static func lastRestart() -> Date? {
        guard let s = try? String(contentsOf: markerURL, encoding: .utf8),
              let t = TimeInterval(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    private static func stampRestart() {
        try? String(Date().timeIntervalSince1970).write(to: markerURL, atomically: true, encoding: .utf8)
    }

    /// 退出当前进程,并让一个分离的子进程在我们退出后重新 open 这个 .app。
    private static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // 等当前进程退出后再 open,避免 LSUIElement 下重复实例 / open 仅激活而不新启。
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"\(path)\""]
        try? task.run()
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}
