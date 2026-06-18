import CoreGraphics
import Foundation

/// 16x16 外观无关的灰度指纹及欧氏距离。
/// "外观无关"指取各像素与均值的绝对偏差,使同一字形的深色/浅色两种渲染
/// 映射到相同的特征向量。
public enum Fingerprint {
    public static let side = 16

    public static func signature(_ image: CGImage) -> [Double] {
        let buf = image.rgbaBuffer(side: side)
        var v = [Double](repeating: 0, count: side * side)
        for i in 0..<(side * side) {
            let o = i * 4
            v[i] = 0.299 * Double(buf[o]) + 0.587 * Double(buf[o + 1]) + 0.114 * Double(buf[o + 2])
        }
        let mean = v.reduce(0, +) / Double(v.count)
        for i in 0..<v.count { v[i] = abs(v[i] - mean) }
        let norm = (v.reduce(0) { $0 + $1 * $1 }).squareRoot()
        if norm > 1e-6 { for i in 0..<v.count { v[i] /= norm } }
        return v
    }

    /// 是否为"空白"指纹:无内容的图(全透明/纯色)经 signature 处理后偏差为 0、
    /// 不会被归一化,故向量近似全 0(能量≈0);有字形的图归一化后能量≈1。
    /// 用于校准时拒绝抓到的空白帧(HUD 尚未画好/已消失那一瞬)。
    public static func isBlank(_ sig: [Double]) -> Bool {
        sig.reduce(0) { $0 + $1 * $1 } < 0.25
    }

    public static func distance(_ a: [Double], _ b: [Double]) -> Double {
        precondition(a.count == b.count)
        var s = 0.0
        for i in 0..<a.count { let d = a[i] - b[i]; s += d * d }
        return s.squareRoot()
    }
}
