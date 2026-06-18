import XCTest
@testable import IMEmoryCore

final class IMERegistryTests: XCTestCase {
    func testLookupDoubao() {
        let d = IMERegistry.lookup(inputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin")
        XCTAssertEqual(d?.key, "doubao")
    }

    func testLookupSogou() {
        let d = IMERegistry.lookup(inputSourceID: "com.sogou.inputmethod.sogou")
        XCTAssertEqual(d?.key, "sogou")
    }

    func testLookupWetype() {
        let d = IMERegistry.lookup(inputSourceID: "com.tencent.inputmethod.wetype")
        XCTAssertEqual(d?.key, "wetype")
    }

    func testUnknownReturnsNil() {
        XCTAssertNil(IMERegistry.lookup(inputSourceID: "com.apple.keylayout.ABC"))
    }

    func testHudSizeRangeAccepts28() {
        let d = IMERegistry.lookup(inputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin")!
        XCTAssertTrue(d.hudSizeRange.contains(28))
    }
}
