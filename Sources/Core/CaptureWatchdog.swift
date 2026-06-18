import Foundation

/// 屏幕捕获"失效"看门狗。
///
/// 背景:macOS 会在 app 长时间运行(尤其跨睡眠/系统回收 TCC)后掐断其屏幕录制授权,
/// 运行中的进程从此一直拿到空帧(`screencapture` 返回 nil 或黑图),且不会自愈——
/// 只有重启进程才能重新拿到有效授权。
///
/// 本计数器只统计"已定位到 HUD 窗口、却读不出中/英"的坏读;一旦连续坏读达到阈值,
/// 就判定捕获流失效。空闲时(屏幕上没有 HUD)既不计坏读也不复位,避免误判。
public final class CaptureWatchdog {
    private let threshold: Int
    public private(set) var consecutiveBad = 0

    /// - Parameter threshold: 连续坏读多少次判定失效。正常切换 1~2 次即能读回,
    ///   故默认 10 足以避开偶发 blank,又能在真正卡死时快速触发。
    public init(threshold: Int = 10) {
        self.threshold = max(1, threshold)
    }

    /// 记一次坏读(定位到 HUD 但截图失败或无法分类)。
    /// - Returns: 是否"刚好跨过阈值"。返回 true 时内部已复位,避免连发。
    public func recordBadRead() -> Bool {
        consecutiveBad += 1
        if consecutiveBad >= threshold {
            consecutiveBad = 0
            return true
        }
        return false
    }

    /// 记一次好读(成功识别为中/英),清零计数。
    public func recordGoodRead() {
        consecutiveBad = 0
    }
}
