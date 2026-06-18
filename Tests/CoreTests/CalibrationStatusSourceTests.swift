import XCTest
@testable import IMEmoryCore

final class CalibrationStatusSourceTests: XCTestCase {
    private func tmpStore() -> TemplateStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("imemory-tmpl-\(UUID().uuidString)", isDirectory: true)
        return TemplateStore(root: dir)
    }
    private func sig() -> [Double] { Array(repeating: 0.1, count: Fingerprint.side * Fingerprint.side) }
    private let src = "com.bytedance.inputmethod.doubaoime.pinyin"

    func testMissingBothWhenEmpty() {
        XCTAssertEqual(CalibrationStatus.missing(store: tmpStore(), sourceID: src), [.light, .dark])
    }

    func testMissingDarkAfterLightSaved() throws {
        let s = tmpStore()
        try s.save(zh: sig(), en: sig(), forSource: src, appearance: .light)
        XCTAssertEqual(CalibrationStatus.missing(store: s, sourceID: src), [.dark])
    }

    func testCompleteAfterBothSaved() throws {
        let s = tmpStore()
        try s.save(zh: sig(), en: sig(), forSource: src, appearance: .light)
        try s.save(zh: sig(), en: sig(), forSource: src, appearance: .dark)
        XCTAssertEqual(CalibrationStatus.missing(store: s, sourceID: src), [])
    }
}
