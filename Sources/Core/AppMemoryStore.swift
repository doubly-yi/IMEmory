import Foundation

public extension Notification.Name {
    /// 记忆/排除发生变化时广播,供 UI 即时刷新(替代轮询)。
    static let imemoryStoreChanged = Notification.Name("imemoryStoreChanged")
}

/// 基于 JSON 的按应用记忆存储,保存每个应用的中/英记录及排除列表。每次修改后立即持久化。
public final class AppMemoryStore {
    private struct Disk: Codable {
        var records: [String: AppRecord] = [:]
        var excluded: Set<String> = []
    }

    private let file: URL
    private var data: Disk
    private let clock: () -> Date

    public init(file: URL, clock: @escaping () -> Date = Date.init) {
        self.file = file
        self.clock = clock
        if let raw = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode(Disk.self, from: raw) {
            self.data = decoded
        } else {
            self.data = Disk()
        }
    }

    /// 默认路径:~/Library/Application Support/IMEmory/memory.json
    public static func defaultStore() -> AppMemoryStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IMEmory", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return AppMemoryStore(file: base.appendingPathComponent("memory.json"))
    }

    public func mode(for bundleId: String) -> IMEMode? { data.records[bundleId]?.mode }

    public func record(bundleId: String, mode: IMEMode) {
        data.records[bundleId] = AppRecord(bundleId: bundleId, mode: mode, updatedAt: clock())
        persist()
    }

    public func delete(bundleId: String) { data.records[bundleId] = nil; persist() }

    public func allRecords() -> [AppRecord] {
        data.records.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func isExcluded(_ bundleId: String) -> Bool { data.excluded.contains(bundleId) }

    public func setExcluded(_ bundleId: String, _ excluded: Bool) {
        if excluded { data.excluded.insert(bundleId) } else { data.excluded.remove(bundleId) }
        persist()
    }

    public func excludedList() -> [String] { data.excluded.sorted() }

    private func persist() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let raw = try? JSONEncoder().encode(data) { try? raw.write(to: file, options: .atomic) }
        NotificationCenter.default.post(name: .imemoryStoreChanged, object: nil)
    }
}
