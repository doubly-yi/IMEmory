import XCTest
@testable import IMEmoryCore

final class SwitchDecisionTests: XCTestCase {
    func testSwitchesToRememberedMode() {
        let d = SwitchDecision.onActivate(
            newApp: "B", currentMode: .en,
            savedModeForNewApp: .zh, newAppExcluded: false)
        XCTAssertEqual(d.switchTo, .zh)
    }

    func testNoSwitchWhenAlreadyInRememberedMode() {
        let d = SwitchDecision.onActivate(
            newApp: "B", currentMode: .zh,
            savedModeForNewApp: .zh, newAppExcluded: false)
        XCTAssertNil(d.switchTo)
    }

    func testNoSwitchWhenNoMemory() {
        let d = SwitchDecision.onActivate(
            newApp: "B", currentMode: .en,
            savedModeForNewApp: nil, newAppExcluded: false)
        XCTAssertNil(d.switchTo)
    }

    func testExcludedAppNeverSwitches() {
        let d = SwitchDecision.onActivate(
            newApp: "B", currentMode: .en,
            savedModeForNewApp: .zh, newAppExcluded: true)
        XCTAssertNil(d.switchTo)
    }

    func testUnknownCurrentModeStillAttemptsRestore() {
        // 当前态未知(没观测到)时,仍尝试恢复进入 App 的记忆模式。
        let d = SwitchDecision.onActivate(
            newApp: "B", currentMode: nil,
            savedModeForNewApp: .zh, newAppExcluded: false)
        XCTAssertEqual(d.switchTo, .zh)
    }
}
