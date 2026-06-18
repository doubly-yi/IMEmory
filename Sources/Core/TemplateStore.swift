import Foundation

/// 将中/英模板以纯文本签名文件的形式持久化,以输入法为 key,
/// 对外观敏感的输入法还会额外区分浅色/深色模式。
public struct TemplateStore {
    public struct Pair { public let zh: [Double]; public let en: [Double] }

    private let root: URL

    public init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// 默认路径:~/Library/Application Support/IMEmory/templates
    public static func defaultStore() -> TemplateStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IMEmory/templates", isDirectory: true)
        return TemplateStore(root: base)
    }

    private func tag(_ def: IMEDef, _ appearance: Appearance) -> String {
        // 所有输入法统一按外观(浅/深)分别存模板。
        "\(def.key)_\(appearance.rawValue)"
    }
    private func url(_ which: String, _ def: IMEDef, _ appearance: Appearance) -> URL {
        root.appendingPathComponent("tmpl_\(which)_\(tag(def, appearance)).sig")
    }

    public func save(zh: [Double], en: [Double], for def: IMEDef, appearance: Appearance) throws {
        try encode(zh).write(to: url("zh", def, appearance), atomically: true, encoding: .utf8)
        try encode(en).write(to: url("en", def, appearance), atomically: true, encoding: .utf8)
    }

    public func load(for def: IMEDef, appearance: Appearance) -> Pair? {
        guard let zh = decode(url("zh", def, appearance)),
              let en = decode(url("en", def, appearance)) else { return nil }
        return Pair(zh: zh, en: en)
    }

    public func has(_ def: IMEDef, appearance: Appearance) -> Bool {
        load(for: def, appearance: appearance) != nil
    }

    private func encode(_ v: [Double]) -> String { v.map { String($0) }.joined(separator: " ") }
    private func decode(_ url: URL) -> [Double]? {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let v = s.split(separator: " ").compactMap { Double($0) }
        return v.count == Fingerprint.side * Fingerprint.side ? v : nil
    }
}
