import CoreGraphics
import ImageIO
import Foundation

/// 通过 /usr/sbin/screencapture 按窗口号截取单个窗口的像素。
/// (CGWindowListCreateImage 在 macOS 15 中已被移除,CLI 工具是目前受支持的方式。)
public enum ScreenCapture {
    public static func captureWindow(_ windowNumber: Int,
                                     to path: String = NSTemporaryDirectory() + "imemory_cap.png") -> CGImage? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l", "\(windowNumber)", path]
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        guard p.terminationStatus == 0 else { return nil }
        return decodedImage(atPath: path)
    }

    /// 从 PNG 文件读出一张**与文件解耦**的位图:立即解码并重绘到独立内存。
    /// 否则 CGImageSourceCreateImageAtIndex 返回的图是惰性读文件的——当同一临时文件被
    /// 下一次截图覆盖后,先前持有的 CGImage 渲染时会读到新内容(校准两张样本预览串成同一张)。
    static func decodedImage(atPath path: String) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(
                src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        let w = img.width, h = img.height
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return img }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? img
    }
}
