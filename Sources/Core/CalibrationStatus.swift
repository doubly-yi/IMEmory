/// 计算某输入法还缺哪些外观槽的模板。
/// 所有输入法统一:浅色、深色各需一套模板。
public enum CalibrationStatus {
    public static func missing(store: TemplateStore, def: IMEDef) -> [Appearance] {
        [.light, .dark].filter { !store.has(def, appearance: $0) }
    }
}
