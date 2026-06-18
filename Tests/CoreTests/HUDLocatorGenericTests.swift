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

    func testPicksNewestWindowWhenStalePopupLingers() {
        // 连续按 Shift 时上一个状态的弹窗还没消失:同一 pid 出现两个都符合的小窗。
        // 旧弹窗(窗号小)是上一个状态,新弹窗(窗号大)才是当前状态——必须取窗号最大的,
        // 否则会抓到残留的旧弹窗(复现:中态抓取后不让消失、再切英抓取,结果两张都是中)。
        let stale = win(100, pid: 99, w: 28, h: 28, layer: 2147483628)   // 旧状态残留
        let fresh = win(105, pid: 99, w: 28, h: 28, layer: 2147483628)   // 当前状态
        XCTAssertEqual(HUDLocator.find(in: [stale, fresh], pid: 99), 105)
        XCTAssertEqual(HUDLocator.find(in: [fresh, stale], pid: 99), 105)  // 与列表顺序无关
    }
}
