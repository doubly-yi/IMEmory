/// 纯状态机:从全局键盘的 flagsChanged / keyDown 序列判定"Shift 单击"(中/英切换手势)。
/// "单击" = Shift 单独按下→抬起,期间没有按下其它键、也没有其它修饰键参与。
/// 用于区分 Shift+字母(打大写)。无任何系统依赖,便于单测。
public struct ShiftTapDetector {
    private var armed = false   // Shift 已干净按下、尚未被其它键/修饰键破坏

    public init() {}

    /// 处理一次 flagsChanged。
    /// - Parameters:
    ///   - shiftPressed: 该事件后 Shift 是否处于按下。
    ///   - anyOtherModifier: 该事件后是否有除 Shift 外的修饰键按下(Cmd/Option/Control/Fn 等)。
    /// - Returns: 是否刚完成一次"Shift 单击"。
    public mutating func handleFlagsChanged(shiftPressed: Bool, anyOtherModifier: Bool) -> Bool {
        if shiftPressed && !anyOtherModifier {
            armed = true            // Shift 干净按下
            return false
        }
        let fired = armed && !shiftPressed && !anyOtherModifier
        armed = false
        return fired
    }

    /// 期间按下了其它键(字母等)→ 破坏单击(是 Shift+键,不是切换)。
    public mutating func handleKeyDown() { armed = false }
}
