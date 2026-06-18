import XCTest
@testable import IMEmoryCore

final class SmokeTests: XCTestCase {
    func testVersionPresent() {
        XCTAssertEqual(IMEmoryCore.version, "0.1.0")
    }

    func testTestImageMakerProducesImage() {
        let img = TestImages.glyphA()
        XCTAssertEqual(img.width, 28)
        XCTAssertEqual(img.height, 28)
    }
}
