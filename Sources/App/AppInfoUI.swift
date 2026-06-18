import AppKit
import CoreServices

/// bundleId → 本地化显示名(与 Finder/聚焦一致,如 Safari→Safari浏览器、Finder→访达、微信、输入定格)。
/// 用 Spotlight 元数据 kMDItemDisplayName 读取系统本地化名,不硬编码;读不到再回退。
enum AppInfoUI {
    static func displayName(forBundleId bid: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) else {
            return bid
        }
        if let item = MDItemCreate(kCFAllocatorDefault, url.path as CFString),
           let name = MDItemCopyAttribute(item, kMDItemDisplayName) as? String, !name.isEmpty {
            return name.replacingOccurrences(of: ".app", with: "")
        }
        // 回退:Finder 显示名
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }
}
