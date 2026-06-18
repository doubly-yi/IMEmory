import XCTest
@testable import IMEmoryCore

final class TemplateStoreSourceTests: XCTestCase {
    private func tmpDir() -> URL {
        let d = FileManager.default.temporaryDirectory
            .appendingPathComponent("imemory-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private func sig() -> [Double] { Array(repeating: 0.1, count: Fingerprint.side * Fingerprint.side) }
    private let src = "com.sogou.inputmethod.sogou.pinyin"

    func testSanitizeReplacesNonAlnum() {
        XCTAssertEqual(TemplateStore.sanitize("com.sogou.inputmethod.sogou.pinyin"),
                       "com_sogou_inputmethod_sogou_pinyin")
    }

    func testSaveLoadRoundTripBySource() throws {
        let store = TemplateStore(root: tmpDir())
        try store.save(zh: sig(), en: sig(), forSource: src, appearance: .light)
        XCTAssertNotNil(store.load(forSource: src, appearance: .light))
        XCTAssertEqual(store.load(forSource: src, appearance: .light)?.zh.count,
                       Fingerprint.side * Fingerprint.side)
    }

    func testAppearancesStoredSeparately() throws {
        let store = TemplateStore(root: tmpDir())
        try store.save(zh: sig(), en: sig(), forSource: src, appearance: .light)
        XCTAssertTrue(store.has(forSource: src, appearance: .light))
        XCTAssertFalse(store.has(forSource: src, appearance: .dark))
    }
}
