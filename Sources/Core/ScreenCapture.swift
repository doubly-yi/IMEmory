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
        guard p.terminationStatus == 0,
              let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return img
    }
}
