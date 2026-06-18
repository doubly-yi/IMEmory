import XCTest
@testable import IMEmoryCore

final class CalibrationStatusTests: XCTestCase {
    private func tmpStore() -> TemplateStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("imemory-tmpl-\(UUID().uuidString)", isDirectory: true)
        return TemplateStore(root: dir)
    }
    private func sig() -> [Double] { Array(repeating: 0.1, count: Fingerprint.side * Fingerprint.side) }
    private var doubao: IMEDef { IMERegistry.all.first { $0.key == "doubao" }! }
    private var sogou: IMEDef { IMERegistry.all.first { $0.key == "sogou" }! }

    // 所有输入法统一:浅、深各需一套模板。

    func testMissingBothWhenEmpty() {
        let s = tmpStore()
        XCTAssertEqual(CalibrationStatus.missing(store: s, def: doubao), [.light, .dark])
    }

    func testMissingDarkAfterLightSaved() throws {
        let s = tmpStore()
        try s.save(zh: sig(), en: sig(), for: doubao, appearance: .light)
        XCTAssertEqual(CalibrationStatus.missing(store: s, def: doubao), [.dark])
    }

    func testCompleteAfterBothSaved() throws {
        let s = tmpStore()
        try s.save(zh: sig(), en: sig(), for: sogou, appearance: .light)
        try s.save(zh: sig(), en: sig(), for: sogou, appearance: .dark)
        XCTAssertEqual(CalibrationStatus.missing(store: s, def: sogou), [])
    }
}
