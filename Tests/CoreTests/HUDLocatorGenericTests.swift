import XCTest
@testable import IMEmoryCore

final class HUDLocatorGenericTests: XCTestCase {
    private func win(_ number: Int, pid: Int, w: Int, h: Int, layer: Int) -> [String: Any] {
        ["kCGWindowNumber": number, "kCGWindowOwnerPID": pid, "kCGWindowLayer": layer,
         "kCGWindowBounds": ["X": 0, "Y": 0, "Width": Double(w), "Height": Double(h)]]
    }

    func testPicksSmallHighLayerWindowOwnedByPid() {
        let windows = [
            win(1, pid: 99, w: 494, h: 64, layer: 2147483628),   // 候选栏(过宽)
            win(2, pid: 99, w: 28, h: 28, layer: 2147483628),    // 目标 HUD
            win(3, pid: 600, w: 29, h: 28, layer: 2147483630),   // Window Server 噪音(别的 pid)
        ]
        XCTAssertEqual(HUDLocator.find(in: windows, pid: 99), 2)
    }

    func testExcludesNormalLayerSmallWindow() {
        let windows = [win(5, pid: 99, w: 28, h: 28, layer: 3)]
        XCTAssertNil(HUDLocator.find(in: windows, pid: 99))
    }

    func testReturnsNilWhenNoneOwnedByPid() {
        let windows = [win(3, pid: 600, w: 29, h: 28, layer: 2147483630)]
        XCTAssertNil(HUDLocator.find(in: windows, pid: 99))
    }
}
