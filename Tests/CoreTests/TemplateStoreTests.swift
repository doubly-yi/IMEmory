import XCTest
@testable import IMEmoryCore

final class TemplateStoreTests: XCTestCase {
    private func tmpDir() -> URL {
        let d = FileManager.default.temporaryDirectory
            .appendingPathComponent("imemory-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testSaveLoadRoundTrip() throws {
        let store = TemplateStore(root: tmpDir())
        let def = IMERegistry.lookup(inputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin")!
        let zh = Fingerprint.signature(TestImages.glyphA())
        let en = Fingerprint.signature(TestImages.glyphB())
        try store.save(zh: zh, en: en, for: def, appearance: .light)

        let loaded = store.load(for: def, appearance: .light)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.zh.count, 256)
        XCTAssertEqual(Fingerprint.distance(loaded!.zh, zh), 0, accuracy: 1e-9)
    }

    func testAppearancesAreStoredSeparately() throws {
        // 所有输入法统一按外观分别存:以 "light" 保存的模板在 "dark" 下找不到。
        let store = TemplateStore(root: tmpDir())
        let def = IMERegistry.lookup(inputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin")!
        try store.save(zh: Fingerprint.signature(TestImages.glyphA()),
                       en: Fingerprint.signature(TestImages.glyphB()),
                       for: def, appearance: .light)
        XCTAssertNotNil(store.load(for: def, appearance: .light))
        XCTAssertNil(store.load(for: def, appearance: .dark))
    }

    func testMissingReturnsNil() {
        let store = TemplateStore(root: tmpDir())
        let def = IMERegistry.lookup(inputSourceID: "com.sogou.inputmethod.sogou")!
        XCTAssertNil(store.load(for: def, appearance: .dark))
    }
}
