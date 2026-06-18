import XCTest
@testable import IMEmoryCore

final class ClassifierTests: XCTestCase {
    private func templates() -> (zh: [Double], en: [Double]) {
        (Fingerprint.signature(TestImages.glyphA()),   // 中 模板
         Fingerprint.signature(TestImages.glyphB()))   // 英 模板
    }

    func testClassifiesZh() {
        let t = templates()
        let c = Classifier(zh: t.zh, en: t.en, gate: 0.6)
        XCTAssertEqual(c.classify(TestImages.glyphA()), .zh)
    }

    func testClassifiesEn() {
        let t = templates()
        let c = Classifier(zh: t.zh, en: t.en, gate: 0.6)
        XCTAssertEqual(c.classify(TestImages.glyphB()), .en)
    }

    func testBlankIsGatedOut() {
        let t = templates()
        let c = Classifier(zh: t.zh, en: t.en, gate: 0.6)
        // 空白帧与两个模板的距离均超过门限 → .blank(无字形)
        XCTAssertEqual(c.classify(TestImages.blank()), .blank)
    }
}
