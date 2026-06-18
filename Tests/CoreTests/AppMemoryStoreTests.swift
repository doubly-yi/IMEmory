import XCTest
@testable import IMEmoryCore

final class AppMemoryStoreTests: XCTestCase {
    private func tmpFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("imemory-store-\(UUID().uuidString).json")
    }

    func testRecordAndLookup() {
        let s = AppMemoryStore(file: tmpFile())
        s.record(bundleId: "com.apple.Terminal", mode: .en)
        XCTAssertEqual(s.mode(for: "com.apple.Terminal"), .en)
        XCTAssertNil(s.mode(for: "com.unknown"))
    }

    func testRecordOverwrites() {
        let s = AppMemoryStore(file: tmpFile())
        s.record(bundleId: "a", mode: .en)
        s.record(bundleId: "a", mode: .zh)
        XCTAssertEqual(s.mode(for: "a"), .zh)
    }

    func testDeleteRemovesMemory() {
        let s = AppMemoryStore(file: tmpFile())
        s.record(bundleId: "a", mode: .zh)
        s.delete(bundleId: "a")
        XCTAssertNil(s.mode(for: "a"))
    }

    func testExcludeSet() {
        let s = AppMemoryStore(file: tmpFile())
        XCTAssertFalse(s.isExcluded("a"))
        s.setExcluded("a", true)
        XCTAssertTrue(s.isExcluded("a"))
        s.setExcluded("a", false)
        XCTAssertFalse(s.isExcluded("a"))
    }

    func testPersistsAcrossInstances() {
        let f = tmpFile()
        let s1 = AppMemoryStore(file: f)
        s1.record(bundleId: "a", mode: .zh)
        s1.setExcluded("b", true)
        let s2 = AppMemoryStore(file: f)
        XCTAssertEqual(s2.mode(for: "a"), .zh)
        XCTAssertTrue(s2.isExcluded("b"))
    }

    func testAllRecordsExposed() {
        let s = AppMemoryStore(file: tmpFile())
        s.record(bundleId: "a", mode: .zh)
        s.record(bundleId: "b", mode: .en)
        XCTAssertEqual(Set(s.allRecords().map { $0.bundleId }), ["a", "b"])
    }
}
