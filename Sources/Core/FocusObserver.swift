import ApplicationServices
import AppKit

/// 单个 AXObserver,监听"当前前台 App"的焦点变化(kAXFocusedUIElementChangedNotification)。
/// 焦点一变就回调 onFocusChanged;调用方据此查 FocusProbe.focusedApp() 判断上下文/推进待办。
/// 跟随前台:外部在 App 切换时调用 observe(pid:) 重新指向新 App。需辅助功能权限。
public final class FocusObserver {
    public var onFocusChanged: (() -> Void)?

    private var observer: AXObserver?
    private var observedPid: pid_t = 0

    public init() {}

    /// 把监听重新指向 pid 这个 App。重复指向同一 pid 则无操作。
    public func observe(pid: pid_t) {
        guard pid > 0, pid != observedPid else { return }
        stop()
        var obs: AXObserver?
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverCreate(pid, focusObserverCallback, &obs) == .success, let obs else { return }
        let appEl = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(obs, appEl, kAXFocusedUIElementChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        observer = obs
        observedPid = pid
    }

    public func stop() {
        if let obs = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        observer = nil
        observedPid = 0
    }

    fileprivate func fire() { onFocusChanged?() }
}

/// AXObserver 的 C 回调:经 refcon 取回 FocusObserver 实例并转交。
private func focusObserverCallback(_ observer: AXObserver, _ element: AXUIElement,
                                   _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let me = Unmanaged<FocusObserver>.fromOpaque(refcon).takeUnretainedValue()
    me.fire()
}
