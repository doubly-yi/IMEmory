import Foundation

/// 列表行视图模型:一行对应一个被记忆或被排除的应用。
public struct AppRow: Identifiable, Equatable {
    public let bundleId: String
    public let displayName: String
    public let mode: IMEMode?        // nil = 仅在排除名单、还没有中/英记录
    public let updatedAt: Date?      // nil = 无记录
    public let excluded: Bool
    public var id: String { bundleId }
}

/// 把"已记录"和"排除名单"合并成排序好的展示行(纯逻辑,便于测试)。
/// 排除但还没记录过的 App 也会作为一行出现(状态/时间为空),这样一张表即可管理,
/// 无需单独的排除名单区。displayName 以闭包注入,便于独立验证排序与回退。
public enum AppListPresenter {
    public static func rows(records: [AppRecord],
                            excluded: [String],
                            displayName: (String) -> String?) -> [AppRow] {
        let excludedSet = Set(excluded)
        var byId: [String: AppRow] = [:]
        for r in records {
            byId[r.bundleId] = AppRow(bundleId: r.bundleId,
                                      displayName: displayName(r.bundleId) ?? r.bundleId,
                                      mode: r.mode,
                                      updatedAt: r.updatedAt,
                                      excluded: excludedSet.contains(r.bundleId))
        }
        for bid in excludedSet where byId[bid] == nil {
            byId[bid] = AppRow(bundleId: bid,
                               displayName: displayName(bid) ?? bid,
                               mode: nil, updatedAt: nil, excluded: true)
        }
        return byId.values.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }
}
