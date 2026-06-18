import XCTest
@testable import IMEmoryCore

final class ModeGlyphTests: XCTestCase {
    func testSymbols() {
        XCTAssertEqual(ModeGlyph.symbol(for: .zh), "中")
        XCTAssertEqual(ModeGlyph.symbol(for: .en), "英")
        XCTAssertEqual(ModeGlyph.symbol(for: nil), "?")
    }
}
