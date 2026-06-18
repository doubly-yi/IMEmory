import CoreGraphics
import Foundation

/// 通过合成 Shift 键事件切换输入法的中/英状态。
/// 方案"M2"(验证通过率 10/10):keyDown(0x38) flags=.maskShift,keyUp(0x38)
/// flags 清零,发送到 .cghidEventTap,按住约 80ms。需要辅助功能权限。
public enum Switcher {
    public static func postShiftToggle(holdMs: UInt32 = 80) {
        let src = CGEventSource(stateID: .hidSystemState)
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x38, keyDown: true) {
            down.flags = .maskShift
            down.post(tap: .cghidEventTap)
        }
        usleep(holdMs * 1000)
        if let up = CGEvent(keyboardEventSource: src, virtualKey: 0x38, keyDown: false) {
            up.flags = []
            up.post(tap: .cghidEventTap)
        }
    }
}
