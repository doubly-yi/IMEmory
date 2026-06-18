import XCTest
@testable import IMEmoryCore

final class IMEResolverTests: XCTestCase {
    func testLongestPrefixWins() {
        let apps: [(bundleID: String, pid: Int, name: String)] = [
            ("com.apple.finder", 1, "访达"),
            ("com.sogou", 999, "短前缀"),
            ("com.sogou.inputmethod.sogou", 26838, "搜狗输入法"),
        ]
        let m = IMEResolver.matchApp(sourceID: "com.sogou.inputmethod.sogou.pinyin", apps: apps)
        XCTAssertEqual(m?.pid, 26838)
        XCTAssertEqual(m?.name, "搜狗输入法")
    }

    func testNoMatchReturnsNil() {
        let apps: [(bundleID: String, pid: Int, name: String)] = [("com.apple.finder", 1, "访达")]
        XCTAssertNil(IMEResolver.matchApp(sourceID: "com.sogou.inputmethod.sogou.pinyin", apps: apps))
    }

    func testEmptyBundleIDsIgnored() {
        let apps: [(bundleID: String, pid: Int, name: String)] = [("", 5, "无包名")]
        XCTAssertNil(IMEResolver.matchApp(sourceID: "com.x.y", apps: apps))
    }

    func testEnumeratorDoesNotCrashAndReturnsArray() {
        // 系统相关,内容因机器而异;此处只验证可调用且不崩溃、返回的条目 sourceID 非空。
        let modes = InputSourceEnumerator.selectableInputModes()
        for m in modes { XCTAssertFalse(m.sourceID.isEmpty) }
    }
}
