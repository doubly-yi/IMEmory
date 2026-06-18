import AppKit

/// 每当前台应用切换时触发 `onActivate(bundleId, localizedName)` 回调。
public final class AppMonitor {
    public var onActivate: ((String, String) -> Void)?
    private var observer: NSObjectProtocol?

    public init() {}

    public func start() {
        let nc = NSWorkspace.shared.notificationCenter
        observer = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                  object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else { return }
            self?.onActivate?(bundleId, app.localizedName ?? bundleId)
        }
    }

    public func stop() {
        if let o = observer { NSWorkspace.shared.notificationCenter.removeObserver(o); observer = nil }
    }

    /// 返回当前前台应用(若有)。
    public static func frontmost() -> (bundleId: String, name: String)? {
        guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier
        else { return nil }
        return (id, app.localizedName ?? id)
    }
}
