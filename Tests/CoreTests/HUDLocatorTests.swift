import XCTest
@testable import IMEmoryCore

final class HUDLocatorTests: XCTestCase {
    private func win(_ number: Int, pid: Int, w: Int, h: Int) -> [String: Any] {
        ["kCGWindowNumber": number, "kCGWindowOwnerPID": pid,
         "kCGWindowBounds": ["X": 0, "Y": 0, "Width": Double(w), "Height": Double(h)]]
    }

    func testPicksSquareHUDInRange() {
        let def = IMERegistry.lookup(inputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin")!
        let windows = [win(1, pid: 99, w: 494, h: 64),   // 候选栏(过宽)
                       win(2, pid: 99, w: 28, h: 28),    // HUD 窗口
                       win(3, pid: 77, w: 28, h: 28)]    // 其他进程
        XCTAssertEqual(HUDLocator.find(in: windows, pid: 99, def: def), 2)
    }

    func testReturnsNilWhenNoHUD() {
        let def = IMERegistry.lookup(inputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin")!
        let windows = [win(1, pid: 99, w: 494, h: 64)]
        XCTAssertNil(HUDLocator.find(in: windows, pid: 99, def: def))
    }
}
