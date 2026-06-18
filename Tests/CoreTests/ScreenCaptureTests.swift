import XCTest
import CoreGraphics
import ImageIO
@testable import IMEmoryCore

final class ScreenCaptureTests: XCTestCase {
    private func writePNG(_ img: CGImage, to url: URL) {
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }

    /// 复现并锁定"校准预览串图"根因:decodedImage 返回的图必须与源文件解耦——
    /// 即便随后用另一张图覆盖同一文件,先前取得的 CGImage 内容也不应改变。
    /// (惰性读文件的实现会在覆盖后读到新内容,导致两张样本预览显示同一张。)
    func testDecodedImageDetachedFromFileAfterOverwrite() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("imemory-sc-\(UUID().uuidString).png")
        writePNG(TestImages.glyphA(), to: url)

        guard let img = ScreenCapture.decodedImage(atPath: url.path) else {
            return XCTFail("decodedImage 返回 nil")
        }
        // 不在覆盖前访问像素,确保惰性实现会在覆盖后读到新内容(从而暴露 bug)。
        writePNG(TestImages.glyphB(), to: url)

        let sig = Fingerprint.signature(img)
        let toA = Fingerprint.distance(sig, Fingerprint.signature(TestImages.glyphA()))
        let toB = Fingerprint.distance(sig, Fingerprint.signature(TestImages.glyphB()))
        XCTAssertEqual(toA, 0, accuracy: 1e-9, "覆盖文件后内容应仍是最初读到的 glyphA")
        XCTAssertGreaterThan(toB, 0.2, "不应变成覆盖后的 glyphB")
    }
}
