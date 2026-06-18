import AppKit

/// 全局键盘监听:用 ShiftTapDetector 识别"Shift 单击",触发 onShiftTap。
/// 需辅助功能权限(全局监听其它 App 的键盘事件)。监听器在主线程注册并回调。
public final class ShiftMonitor {
    public var onShiftTap: (() -> Void)?
    /// 闸门:返回 true 时忽略事件(用于屏蔽我们自己合成的 Shift,防回环)。
    public var isSuppressed: () -> Bool = { false }

    private var detector = ShiftTapDetector()
    private var flagsMonitor: Any?
    private var keyMonitor: Any?

    public init() {}

    public func start() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            guard let self, !self.isSuppressed() else { return }
            let shift = e.modifierFlags.contains(.shift)
            let others: NSEvent.ModifierFlags = [.command, .option, .control, .function]
            let anyOther = !e.modifierFlags.intersection(others).isEmpty
            if self.detector.handleFlagsChanged(shiftPressed: shift, anyOtherModifier: anyOther) {
                self.onShiftTap?()
            }
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            guard let self, !self.isSuppressed() else { return }
            self.detector.handleKeyDown()
        }
    }

    public func stop() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
