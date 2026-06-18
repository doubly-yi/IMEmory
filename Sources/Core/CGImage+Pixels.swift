import CoreGraphics

extension CGImage {
    /// 将自身绘制到指定正方形尺寸的 RGBA8 缓冲区中,返回原始字节数组(w*h*4 字节)。
    func rgbaBuffer(side: Int) -> [UInt8] {
        let bpr = side * 4
        var buf = [UInt8](repeating: 0, count: bpr * side)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &buf, width: side, height: side,
                                  bitsPerComponent: 8, bytesPerRow: bpr, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return buf
        }
        ctx.interpolationQuality = .high
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: side, height: side))
        return buf
    }
}
