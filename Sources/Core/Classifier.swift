import CoreGraphics

public enum IMEMode: String, Equatable, Codable {
    case zh = "中"
    case en = "英"
}

/// 对捕获到的 HUD 帧进行分类后的结果。
public enum ClassifyResult: Equatable {
    case zh
    case en
    case blank   // 无字形(两个距离均超过门限)
}

/// 基于两个校准模板的最近邻分类器,带有空白门限过滤。
public struct Classifier {
    public let zh: [Double]
    public let en: [Double]
    public let gate: Double

    public init(zh: [Double], en: [Double], gate: Double = 0.6) {
        self.zh = zh; self.en = en; self.gate = gate
    }

    public func classify(_ image: CGImage) -> ClassifyResult {
        let sig = Fingerprint.signature(image)
        let dZh = Fingerprint.distance(sig, zh)
        let dEn = Fingerprint.distance(sig, en)
        if min(dZh, dEn) > gate { return .blank }
        return dZh < dEn ? .zh : .en
    }
}
