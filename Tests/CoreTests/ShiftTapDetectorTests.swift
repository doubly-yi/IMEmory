import XCTest
@testable import IMEmoryCore

final class ShiftTapDetectorTests: XCTestCase {
    func testCleanShiftTapFires() {
        var d = ShiftTapDetector()
        XCTAssertFalse(d.handleFlagsChanged(shiftPressed: true, anyOtherModifier: false))   // Shift 按下
        XCTAssertTrue(d.handleFlagsChanged(shiftPressed: false, anyOtherModifier: false))    // Shift 抬起 → 单击
    }

    func testShiftPlusKeyDoesNotFire() {
        var d = ShiftTapDetector()
        _ = d.handleFlagsChanged(shiftPressed: true, anyOtherModifier: false)   // Shift 按下
        d.handleKeyDown()                                                       // 期间按了字母
        XCTAssertFalse(d.handleFlagsChanged(shiftPressed: false, anyOtherModifier: false))   // 抬起 → 不算单击
    }

    func testShiftPlusOtherModifierDoesNotFire() {
        var d = ShiftTapDetector()
        _ = d.handleFlagsChanged(shiftPressed: true, anyOtherModifier: false)
        XCTAssertFalse(d.handleFlagsChanged(shiftPressed: true, anyOtherModifier: true))
        XCTAssertFalse(d.handleFlagsChanged(shiftPressed: false, anyOtherModifier: false))
    }

    func testReleaseWithoutArmDoesNotFire() {
        var d = ShiftTapDetector()
        XCTAssertFalse(d.handleFlagsChanged(shiftPressed: false, anyOtherModifier: false))
    }
}
