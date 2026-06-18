import Foundation

/// 单条应用记录:包含 bundle id、上次记忆的中/英模式及更新时间。
public struct AppRecord: Codable, Equatable {
    public let bundleId: String
    public var mode: IMEMode
    public var updatedAt: Date

    public init(bundleId: String, mode: IMEMode, updatedAt: Date) {
        self.bundleId = bundleId; self.mode = mode; self.updatedAt = updatedAt
    }
}
