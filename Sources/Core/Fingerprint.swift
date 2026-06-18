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

    public static func distance(_ a: [Double], _ b: [Double]) -> Double {
        precondition(a.count == b.count)
        var s = 0.0
        for i in 0..<a.count { let d = a[i] - b[i]; s += d * d }
        return s.squareRoot()
    }
}
