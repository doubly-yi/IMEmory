import Foundation

/// 一个已知输入法的定义:包含识别方式、进程查找方式及 HUD 读取参数。
public struct IMEDef: Equatable, Identifiable {
    public var id: String { key }
    public let key: String              // 稳定的模板标识符,例如 "doubao"
    public let displayName: String
    public let bundlePrefix: String     // 与 TIS 输入源 id 进行前缀匹配
    public let processMatch: String     // 用于 pgrep -f 匹配输入法进程的模式串
    public let hudSizeRange: ClosedRange<Int>   // HUD 正方形边长的接受范围(像素)
    // 注:所有输入法统一按系统外观(浅/深)分别建立模板——即使某输入法浅深一样,
    //     存两份也无害,这样无需逐个判断是否对外观敏感,更通用更稳。
}

public enum IMERegistry {
    public static let all: [IMEDef] = [
        IMEDef(key: "doubao", displayName: "豆包输入法",
               bundlePrefix: "com.bytedance.inputmethod.doubaoime",
               processMatch: "DoubaoIme.app/Contents/MacOS/DoubaoIme",
               hudSizeRange: 20...40),
        IMEDef(key: "wetype", displayName: "微信输入法",
               bundlePrefix: "com.tencent.inputmethod.wetype",
               processMatch: "WeType.app/Contents/MacOS/WeType",
               hudSizeRange: 18...40),
        IMEDef(key: "sogou", displayName: "搜狗拼音",
               bundlePrefix: "com.sogou.inputmethod.sogou",
               processMatch: "SogouInput.app/Contents/MacOS/SogouInput",
               hudSizeRange: 24...48),
    ]

    public static func lookup(inputSourceID: String) -> IMEDef? {
        all.first { inputSourceID.hasPrefix($0.bundlePrefix) }
    }
}
