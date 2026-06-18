import os
import Foundation

/// 统一日志:同时写
///  ① 文件 `~/Library/Application Support/IMEmory/imemory.log`(最稳,随时 cat/tail 查看)
///  ② os.Logger(subsystem com.imemory.app,供 Console.app 查看)
public enum Log {
    private static let osLog = Logger(subsystem: "com.imemory.app", category: "imemory")
    private static let queue = DispatchQueue(label: "com.imemory.log")

    /// 日志文件路径(与 templates/memory.json 同目录)。
    public static let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IMEmory", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("imemory.log")
    }()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm:ss.SSS"; return f
    }()

    private static func write(_ category: String, _ m: String) {
        osLog.notice("[\(category, privacy: .public)] \(m, privacy: .public)")
        let stamp = dateFmt.string(from: Date())
        queue.async {
            let line = "\(stamp) [\(category)] \(m)\n"
            guard let data = line.data(using: .utf8) else { return }
            // 文件超过 ~512KB 时清空,避免无限增长。
            if let size = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int,
               size > 512 * 1024 {
                try? Data().write(to: fileURL)
            }
            if let h = try? FileHandle(forWritingTo: fileURL) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: fileURL)   // 文件不存在则创建
            }
        }
    }

    /// 采样/状态识别相关。
    public static func track(_ m: String) { write("tracker", m) }
    /// 自动切换/记忆/恢复相关。
    public static func sw(_ m: String) { write("switch", m) }
    /// App 生命周期/通用。
    public static func app(_ m: String) { write("app", m) }
}
