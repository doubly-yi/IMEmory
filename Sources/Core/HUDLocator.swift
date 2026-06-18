import CoreGraphics
import Foundation

/// 在屏幕上的窗口列表中定位输入法的中/英 HUD 窗口。
public enum HUDLocator {
    /// 通用尺寸/层级判据(取代每个输入法的 hudSizeRange 魔数)。
    static let sizeRange = 12...70
    static let minHUDLayer = 1_000_000

    /// 对注入的窗口信息列表进行纯过滤(便于测试)。
    public static func find(in windows: [[String: Any]], pid: Int, def: IMEDef) -> Int? {
        for w in windows {
            guard (w["kCGWindowOwnerPID"] as? Int) == pid,
                  let n = w["kCGWindowNumber"] as? Int,
                  let b = w["kCGWindowBounds"] as? [String: Any] else { continue }
            let ww = Int((b["Width"] as? Double) ?? 0)
            let hh = Int((b["Height"] as? Double) ?? 0)
            if def.hudSizeRange.contains(ww), def.hudSizeRange.contains(hh), abs(ww - hh) <= 24 {
                return n
            }
        }
        return nil
    }

    /// 通用 HUD 过滤(纯函数,便于测试):属主=pid + 近正方小窗 + 超高层级。
    public static func find(in windows: [[String: Any]], pid: Int) -> Int? {
        for w in windows {
            guard (w["kCGWindowOwnerPID"] as? Int) == pid,
                  let n = w["kCGWindowNumber"] as? Int,
                  let b = w["kCGWindowBounds"] as? [String: Any] else { continue }
            let ww = Int((b["Width"] as? Double) ?? 0)
            let hh = Int((b["Height"] as? Double) ?? 0)
            let layer = (w["kCGWindowLayer"] as? Int) ?? 0
            if sizeRange.contains(ww), sizeRange.contains(hh),
               abs(ww - hh) <= 24, layer > minHUDLayer {
                return n
            }
        }
        return nil
    }

    /// 实时版本:向窗口服务器查询当前屏幕上的窗口。
    public static func findOnScreen(pid: Int, def: IMEDef) -> Int? {
        let arr = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                   as? [[String: Any]]) ?? []
        // CFDictionary 的 key 以 CFString 传入,此处统一转换为 String 类型的 key。
        let normalized = arr.map { dict -> [String: Any] in
            var out: [String: Any] = [:]
            if let n = dict[kCGWindowNumber as String] { out["kCGWindowNumber"] = n }
            if let p = dict[kCGWindowOwnerPID as String] { out["kCGWindowOwnerPID"] = p }
            if let b = dict[kCGWindowBounds as String] as? [String: Any] { out["kCGWindowBounds"] = b }
            return out
        }
        return find(in: normalized, pid: pid, def: def)
    }

    /// 实时版本:向窗口服务器查询当前在屏窗口,按通用判据定位。
    public static func findOnScreen(pid: Int) -> Int? {
        let arr = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                   as? [[String: Any]]) ?? []
        let normalized = arr.map { dict -> [String: Any] in
            var out: [String: Any] = [:]
            if let n = dict[kCGWindowNumber as String] { out["kCGWindowNumber"] = n }
            if let p = dict[kCGWindowOwnerPID as String] { out["kCGWindowOwnerPID"] = p }
            if let l = dict[kCGWindowLayer as String] { out["kCGWindowLayer"] = l }
            if let b = dict[kCGWindowBounds as String] as? [String: Any] { out["kCGWindowBounds"] = b }
            return out
        }
        return find(in: normalized, pid: pid)
    }

    /// 诊断信息:当前可枚举的在屏窗口总数、属于某 pid 的窗口数及其尺寸。
    /// 用于区分"找不到 HUD"的原因:窗口总数极少→多半缺屏幕录制权限(macOS 15+ 枚举他 App 窗口需此权限)。
    public static func onScreenDiagnostics(pid: Int) -> (total: Int, mine: Int, sizes: [String]) {
        let arr = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                   as? [[String: Any]]) ?? []
        var mine = 0
        var sizes: [String] = []
        for d in arr where (d[kCGWindowOwnerPID as String] as? Int) == pid {
            mine += 1
            if let b = d[kCGWindowBounds as String] as? [String: Any] {
                let w = Int((b["Width"] as? Double) ?? 0)
                let h = Int((b["Height"] as? Double) ?? 0)
                sizes.append("\(w)x\(h)")
            }
        }
        return (arr.count, mine, sizes)
    }

    /// 诊断:列出所有 HUD 尺寸范围内的在屏小窗(属主名#pid:WxH),排除菜单栏等噪声。
    /// 用于排查"明明弹出了小窗却没匹配到"——看 app 到底枚举得到哪些小窗。
    public static func allSmallWindows() -> [String] {
        let noise: Set<String> = ["控制中心", "Control Center", "BetterDisplay", "Window Server", "Dock"]
        let arr = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                   as? [[String: Any]]) ?? []
        var out: [String] = []
        for d in arr {
            guard let b = d[kCGWindowBounds as String] as? [String: Any] else { continue }
            let w = Int((b["Width"] as? Double) ?? 0)
            let h = Int((b["Height"] as? Double) ?? 0)
            guard w >= 10, h >= 10, max(w, h) <= 70 else { continue }
            let owner = d[kCGWindowOwnerName as String] as? String ?? "?"
            if noise.contains(owner) { continue }
            let pid = d[kCGWindowOwnerPID as String] as? Int ?? -1
            out.append("\(owner)#\(pid):\(w)x\(h)")
        }
        return out
    }
}
