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

    /// 把输入源 ID 转成安全文件名:非字母数字一律换成下划线。
    public static func sanitize(_ sourceID: String) -> String {
        String(sourceID.map { ($0.isLetter || $0.isNumber) ? $0 : "_" })
    }

    private func tagSource(_ sourceID: String, _ appearance: Appearance) -> String {
        "\(Self.sanitize(sourceID))_\(appearance.rawValue)"
    }
    private func urlSource(_ which: String, _ sourceID: String, _ appearance: Appearance) -> URL {
        root.appendingPathComponent("tmpl_\(which)_\(tagSource(sourceID, appearance)).sig")
    }

    public func save(zh: [Double], en: [Double], forSource sourceID: String, appearance: Appearance) throws {
        try encode(zh).write(to: urlSource("zh", sourceID, appearance), atomically: true, encoding: .utf8)
        try encode(en).write(to: urlSource("en", sourceID, appearance), atomically: true, encoding: .utf8)
    }
    public func load(forSource sourceID: String, appearance: Appearance) -> Pair? {
        guard let zh = decode(urlSource("zh", sourceID, appearance)),
              let en = decode(urlSource("en", sourceID, appearance)) else { return nil }
        return Pair(zh: zh, en: en)
    }
    public func has(forSource sourceID: String, appearance: Appearance) -> Bool {
        load(forSource: sourceID, appearance: appearance) != nil
    }

    private func encode(_ v: [Double]) -> String { v.map { String($0) }.joined(separator: " ") }
    private func decode(_ url: URL) -> [Double]? {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let v = s.split(separator: " ").compactMap { Double($0) }
        return v.count == Fingerprint.side * Fingerprint.side ? v : nil
    }
}
