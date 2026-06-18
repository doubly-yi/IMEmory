/// 把中/英模式映射为菜单栏显示的单字符;未知态显示问号。
public enum ModeGlyph {
    public static func symbol(for mode: IMEMode?) -> String {
        switch mode {
        case .zh: return "中"
        case .en: return "英"
        case nil: return "?"
        }
    }
}
