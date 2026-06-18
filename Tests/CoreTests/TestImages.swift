import CoreGraphics
import Foundation

enum TestImages {
    /// 生成一张 `side`x`side` 的图像:背景为纯色 `bg`,用 `fg` 填充 `marks` 指定的矩形区域。
    /// 用于合成可区分的"字形状"测试图像,无需真实 PNG 文件。
    static func make(side: Int, bg: CGFloat, fg: CGFloat, marks: [CGRect]) -> CGImage {
        let bpr = side * 4
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                            bytesPerRow: bpr, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: bg, green: bg, blue: bg, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        ctx.setFillColor(red: fg, green: fg, blue: fg, alpha: 1)
        for m in marks { ctx.fill(m) }
        return ctx.makeImage()!
    }

    /// 模拟"中"字形:竖线 + 居中横线。
    static func glyphA(side: Int = 28, bg: CGFloat = 0.1, fg: CGFloat = 0.9) -> CGImage {
        let s = CGFloat(side)
        return make(side: side, bg: bg, fg: fg, marks: [
            CGRect(x: s*0.45, y: s*0.2, width: s*0.1, height: s*0.6),  // 竖线
            CGRect(x: s*0.3, y: s*0.4, width: s*0.4, height: s*0.1),   // 横线
        ])
    }

    /// 模拟"英"字形:笔画更密,分布不同。
    static func glyphB(side: Int = 28, bg: CGFloat = 0.1, fg: CGFloat = 0.9) -> CGImage {
        let s = CGFloat(side)
        return make(side: side, bg: bg, fg: fg, marks: [
            CGRect(x: s*0.2, y: s*0.25, width: s*0.6, height: s*0.1),
            CGRect(x: s*0.25, y: s*0.45, width: s*0.5, height: s*0.1),
            CGRect(x: s*0.3, y: s*0.65, width: s*0.4, height: s*0.12),
            CGRect(x: s*0.45, y: s*0.2, width: s*0.1, height: s*0.5),
        ])
    }

    /// 空白帧:纯色背景,无任何标记。
    static func blank(side: Int = 28, bg: CGFloat = 0.1) -> CGImage {
        return make(side: side, bg: bg, fg: bg, marks: [])
    }
}
