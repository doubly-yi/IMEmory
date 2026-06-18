import XCTest
@testable import IMEmoryCore

final class StateTrackerTests: XCTestCase {
    // 切到不同输入源 → 应重置中/英
    func testDifferentSourceResets() {
        XCTAssertTrue(StateTracker.shouldResetForSourceChange(
            new: "com.sogou.inputmethod.sogou.pinyin",
            last: "com.tencent.inputmethod.wetype.pinyin"))
    }

    // 同一输入源的重复/中英切换通知(搜狗、微信切中英时输入源 ID 不变)→ 不重置
    func testSameSourceDoesNotReset() {
        XCTAssertFalse(StateTracker.shouldResetForSourceChange(
            new: "com.tencent.inputmethod.wetype.pinyin",
            last: "com.tencent.inputmethod.wetype.pinyin"))
    }

    // 首次(尚无 last)读到非空输入源 → 视为变化,允许重置以建立基线
    func testNilLastWithNonEmptyResets() {
        XCTAssertTrue(StateTracker.shouldResetForSourceChange(
            new: "com.bytedance.inputmethod.doubaoime.pinyin", last: nil))
    }

    // 读不到输入源(空)→ 不重置,避免误触
    func testEmptyNewDoesNotReset() {
        XCTAssertFalse(StateTracker.shouldResetForSourceChange(new: "", last: nil))
        XCTAssertFalse(StateTracker.shouldResetForSourceChange(
            new: "", last: "com.sogou.inputmethod.sogou.pinyin"))
    }
}
