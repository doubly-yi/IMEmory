import CoreGraphics
import Foundation

/// 全局键盘监听:用 CGEventTap(只读)在**独立线程**上识别"Shift 单击",触发 onShiftTap。
///
/// 为什么用独立线程的 CGEventTap、而不是 NSEvent 全局监听:
/// NSEvent.addGlobalMonitorForEvents 把事件 tap 的 source 挂在**主 run loop** 上,会与本 App
/// 自己的菜单栏菜单/弹窗的模态事件循环(在主线程)抢占冲突,导致菜单收不到鼠标点击、点不动。
/// 把 tap 放到独立线程的 run loop 上即可彻底解耦:菜单照常工作,Shift 检测也照常(连本 App
/// 在前台时也有效)。需辅助功能权限。
public final class ShiftMonitor {
    public var onShiftTap: (() -> Void)?
    /// 闸门:返回 true 时忽略事件(屏蔽我们自己合成的 Shift,防回环)。跨线程读,需线程安全。
    public var isSuppressed: () -> Bool = { false }

    private var detector = ShiftTapDetector()
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?

    public init() {}

    public func start() {
        guard thread == nil else { return }
        let t = Thread { [weak self] in
            guard let self else { return }
            let mask: CGEventMask =
                (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                              options: .listenOnly, eventsOfInterest: mask,
                                              callback: shiftTapCallback, userInfo: refcon) else {
                Log.track("ShiftMonitor: 无法创建事件 tap(可能缺辅助功能权限)")
                return
            }
            self.tap = tap
            self.runLoop = CFRunLoopGetCurrent()
            let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()   // 独立线程的 run loop,与主线程菜单循环互不干扰
        }
        t.name = "com.imemory.shiftmonitor"
        t.start()
        thread = t
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let rl = runLoop { CFRunLoopStop(rl) }
        tap = nil; runLoop = nil; thread = nil
    }

    /// 在 tap 线程上被回调。
    fileprivate func handle(_ type: CGEventType, _ flags: CGEventFlags) {
        // tap 被系统禁用(回调超时/被用户输入打断)→ 重新启用,保证长期可靠。
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if isSuppressed() { return }
        if type == .keyDown { detector.handleKeyDown(); return }
        // flagsChanged:Shift 是否按下 + 是否有其它修饰键。
        let shift = flags.contains(.maskShift)
        let others: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskSecondaryFn]
        let anyOther = !flags.intersection(others).isEmpty
        if detector.handleFlagsChanged(shiftPressed: shift, anyOtherModifier: anyOther) {
            onShiftTap?()
        }
    }
}

/// CGEventTap 的 C 回调:经 refcon 取回 ShiftMonitor 实例并转交。只读 tap,事件原样放行。
private func shiftTapCallback(proxy: CGEventTapProxy, type: CGEventType,
                              event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let refcon {
        Unmanaged<ShiftMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type, event.flags)
    }
    return Unmanaged.passUnretained(event)
}
