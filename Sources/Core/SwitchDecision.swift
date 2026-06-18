/// 应用激活切换的纯决策逻辑。
/// - `switchTo`:进入应用后应恢复到的记忆模式,若无需/不应切换则为 nil。
///
/// 注:**不再有"离开时记录"**。一个 App 的中/英只在真正观测到小窗(用户在该 App 内
/// 实际切过中英)时由 `StateTracker.onChange` 记录,绝不用全局旧值(tracker.current)
/// 反推。否则在没有输入框/没弹小窗的 App(如 Xcode 文件树、软件设置)里,会把上一个
/// App 残留的状态错记给当前 App,颠覆记忆。
public enum SwitchDecision {
    public struct Outcome: Equatable {
        public let switchTo: IMEMode?
    }

    public static func onActivate(newApp: String,
                                  currentMode: IMEMode?,
                                  savedModeForNewApp: IMEMode?,
                                  newAppExcluded: Bool) -> Outcome {
        var switchTo: IMEMode? = nil
        // 进入的 App 有记忆、未被排除、且与当前态不同(或当前态未知)时,尝试恢复。
        if !newAppExcluded, let target = savedModeForNewApp, target != currentMode {
            switchTo = target
        }
        return Outcome(switchTo: switchTo)
    }
}
