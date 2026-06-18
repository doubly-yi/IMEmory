import XCTest
import CoreGraphics
@testable import IMEmoryCore

final class FingerprintTests: XCTestCase {
    func testSignatureLengthAndNormalized() {
        let sig = Fingerprint.signature(TestImages.glyphA())
        XCTAssertEqual(sig.count, 16 * 16)
        let norm = sqrt(sig.reduce(0) { $0 + $1 * $1 })
        XCTAssertEqual(norm, 1.0, accuracy: 1e-6)   // 单位归一化
    }

    func testSameGlyphSmallDistance() {
        let a = Fingerprint.signature(TestImages.glyphA())
        let b = Fingerprint.signature(TestImages.glyphA())
        XCTAssertEqual(Fingerprint.distance(a, b), 0, accuracy: 1e-9)
    }

    func testDifferentGlyphsLargeDistance() {
        let a = Fingerprint.signature(TestImages.glyphA())
        let b = Fingerprint.signature(TestImages.glyphB())
        XCTAssertGreaterThan(Fingerprint.distance(a, b), 0.2)
    }

    func testAppearanceInvariance() {
        // 相同字形、反转极性(深色背景浅色字 vs 浅色背景深色字)
        // 应产生近乎相同的特征向量。
        let darkMode = TestImages.glyphA(bg: 0.1, fg: 0.9)
        let lightMode = TestImages.glyphA(bg: 0.9, fg: 0.1)
        let d = Fingerprint.distance(Fingerprint.signature(darkMode),
                                     Fingerprint.signature(lightMode))
        XCTAssertLessThan(d, 0.05)
    }
}
