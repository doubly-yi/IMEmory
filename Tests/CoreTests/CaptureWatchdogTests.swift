import XCTest
@testable import IMEmoryCore

final class CaptureWatchdogTests: XCTestCase {
    func testTripsExactlyAtThreshold() {
        let w = CaptureWatchdog(threshold: 3)
        XCTAssertFalse(w.recordBadRead())   // 1
        XCTAssertFalse(w.recordBadRead())   // 2
        XCTAssertTrue(w.recordBadRead())    // 3 → 触发
    }

    func testResetsAfterTripping() {
        let w = CaptureWatchdog(threshold: 2)
        XCTAssertFalse(w.recordBadRead())   // 1
        XCTAssertTrue(w.recordBadRead())    // 2 → 触发并复位
        XCTAssertEqual(w.consecutiveBad, 0)
        XCTAssertFalse(w.recordBadRead())   // 复位后需重新累计
        XCTAssertTrue(w.recordBadRead())
    }

    func testGoodReadResetsCounter() {
        let w = CaptureWatchdog(threshold: 3)
        _ = w.recordBadRead()
        _ = w.recordBadRead()
        w.recordGoodRead()
        XCTAssertEqual(w.consecutiveBad, 0)
        // 好读打断后,偶发坏读不应立即触发。
        XCTAssertFalse(w.recordBadRead())
        XCTAssertFalse(w.recordBadRead())
        XCTAssertTrue(w.recordBadRead())
    }

    func testThresholdFlooredToOne() {
        let w = CaptureWatchdog(threshold: 0)
        XCTAssertTrue(w.recordBadRead())   // 阈值被钳到 1,首次坏读即触发
    }
}
