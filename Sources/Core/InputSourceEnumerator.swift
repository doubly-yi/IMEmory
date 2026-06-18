import Carbon
import Foundation

/// 枚举系统里"可选中的键盘输入模式"(即各中文输入法的模式),不写死任何输入法。
/// 注:TIS API 须在主线程调用;调用方(校准 UI、AppController.init)均在主线程。
public enum InputSourceEnumerator {
    public struct Entry: Identifiable, Equatable {
        public let sourceID: String
        public let displayName: String
        public var id: String { sourceID }
        public init(sourceID: String, displayName: String) {
            self.sourceID = sourceID; self.displayName = displayName
        }
    }

    public static func selectableInputModes() -> [Entry] {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
                as? [TISInputSource] else { return [] }
        var out: [Entry] = []
        for s in list {
            guard str(s, kTISPropertyInputSourceCategory) == (kTISCategoryKeyboardInputSource as String),
                  boolProp(s, kTISPropertyInputSourceIsSelectCapable),
                  let id = str(s, kTISPropertyInputSourceID) else { continue }
            out.append(Entry(sourceID: id, displayName: str(s, kTISPropertyLocalizedName) ?? id))
        }
        return out
    }

    private static func str(_ s: TISInputSource, _ key: CFString) -> String? {
        guard let p = TISGetInputSourceProperty(s, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }
    private static func boolProp(_ s: TISInputSource, _ key: CFString) -> Bool {
        guard let p = TISGetInputSourceProperty(s, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(p).takeUnretainedValue())
    }
}
