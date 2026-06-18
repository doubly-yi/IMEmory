import XCTest
@testable import IMEmoryCore

final class AppListPresenterTests: XCTestCase {
    private func rec(_ id: String, _ mode: IMEMode, _ t: TimeInterval) -> AppRecord {
        AppRecord(bundleId: id, mode: mode, updatedAt: Date(timeIntervalSince1970: t))
    }

    func testSortsByUpdatedAtDescending() {
        let rows = AppListPresenter.rows(
            records: [rec("a", .zh, 100), rec("b", .en, 200)],
            excluded: [],
            displayName: { _ in nil })
        XCTAssertEqual(rows.map { $0.bundleId }, ["b", "a"])
    }

    func testDisplayNameFallsBackToBundleId() {
        let rows = AppListPresenter.rows(
            records: [rec("com.x.app", .zh, 1)],
            excluded: [],
            displayName: { _ in nil })
        XCTAssertEqual(rows.first?.displayName, "com.x.app")
    }

    func testUsesResolvedNameAndExcludedFlag() {
        let rows = AppListPresenter.rows(
            records: [rec("com.x.app", .en, 1)],
            excluded: ["com.x.app"],
            displayName: { _ in "梦幻 App" })
        XCTAssertEqual(rows.first?.displayName, "梦幻 App")
        XCTAssertTrue(rows.first!.excluded)
    }

    func testExcludedOnlyAppAppearsWithoutRecord() {
        let rows = AppListPresenter.rows(
            records: [],
            excluded: ["com.only.excluded"],
            displayName: { _ in nil })
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.bundleId, "com.only.excluded")
        XCTAssertNil(rows.first?.mode)
        XCTAssertTrue(rows.first!.excluded)
    }
}
