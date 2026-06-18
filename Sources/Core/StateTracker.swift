import Carbon
import CoreGraphics
import Foundation

public extension Notification.Name {
    /// 中/英 或 输入法名 变化时广播,供菜单栏即时刷新(取代轮询)。
    static let imemoryStateChanged = Notification.Name("imemoryStateChanged")
}

/// 持续监视当前输入法的 HUD 并维护中/英模式状态。
/// 每当检测到模式变化时触发 `onChange` 回调。冷启动时 `current` 为 nil,
/// 直到首次观测到字形后才确定初始状态。
public final class StateTracker {
    public private(set) var current: IMEMode?
    /// 最近一次成功识别到的输入法显示名(如"豆包")。仅在 resolve 成功时更新,
    /// resolve 失败(如本 app 前台、输入源是 ABC)时保留上一次的好值,供菜单显示。
    public private(set) var currentIMEName: String?
    public var onChange: ((IMEMode) -> Void)?
    /// 连续多次"定位到 HUD 却读不出"→ 判定屏幕捕获流失效时回调(供 App 层自愈,如重启自身)。
    public var onCaptureStuck: (() -> Void)?

    private let store: TemplateStore
    private let shiftMonitor = ShiftMonitor()
    // 合成 Shift 期间为真,屏蔽 ShiftMonitor。跨线程访问(后台写、主线程读)→ 加锁保证可见性。
    private let suppressLock = NSLock()
    private var _suppressShift = false
    private var suppressShift: Bool {
        get { suppressLock.lock(); defer { suppressLock.unlock() }; return _suppressShift }
        set { suppressLock.lock(); _suppressShift = newValue; suppressLock.unlock() }
    }
    private var imeSourceObserver: NSObjectProtocol?
    private var lastNote: String?   // 上次"为何没出状态"的原因,变化时才记日志,避免刷屏
    private var lastIMEKey: String? // 上次解析到的输入法 key,用于检测输入法被切换
    private let watchdog = CaptureWatchdog()  // 捕获失效看门狗

    public init(store: TemplateStore = .defaultStore()) {
        self.store = store
    }

    /// 单次采样:返回本次观测到的模式,若无字形或系统未就绪则返回 nil。
    @discardableResult
    public func sampleOnce() -> IMEMode? {
        guard let r = IMEResolver.resolve() else { note("无活跃的已知输入法"); return nil }
        currentIMEName = r.displayName
        // 输入法被切换(豆包→搜狗等):各输入法中/英相互独立,旧的 current 不再有效,
        // 重置为"未知",避免显示上一个输入法的旧状态;待这个输入法下次出小窗时再读准。
        if lastIMEKey != r.sourceID {
            lastIMEKey = r.sourceID
            if current != nil {
                current = nil
                Log.track("输入法切到 \(r.displayName) → 中/英重置为未知(待读取)")
                NotificationCenter.default.post(name: .imemoryStateChanged, object: nil)
            }
        }
        let appearance = Appearance.current()
        guard let tmpl = store.load(forSource: r.sourceID, appearance: appearance) else {
            note("\(r.displayName) 缺[\(appearance.rawValue)]模板,需校准"); return nil
        }
        guard let win = HUDLocator.findOnScreen(pid: r.pid) else {
            let d = HUDLocator.onScreenDiagnostics(pid: r.pid)
            let small = HUDLocator.allSmallWindows().joined(separator: " ")
            note("\(r.displayName)[pid \(r.pid)] 未发现HUD;"
                 + "该pid窗口[\(d.sizes.joined(separator: ","))];可见小窗[\(small.isEmpty ? "无" : small)]")
            return nil
        }
        guard let img = ScreenCapture.captureWindow(win) else {
            // 截图返回 nil = 捕获流真失效的信号(如系统掐断屏幕录制)。这才计入看门狗。
            note("截图失败(可能缺屏幕录制权限)")
            if watchdog.recordBadRead() { onCaptureStuck?() }
            return nil
        }
        let result = Classifier(zh: tmpl.zh, en: tmpl.en).classify(img)
        switch result {
        case .zh: clearNote(); watchdog.recordGoodRead(); updateIfChanged(.zh); return .zh
        case .en: clearNote(); watchdog.recordGoodRead(); updateIfChanged(.en); return .en
        case .blank:
            // 截到图却分不出中/英:捕获流是好的(拿到像素了),只是内容不匹配 / HUD 正在淡出。
            // 这是正常噪声,**不计入**"捕获失效"看门狗——否则频繁切中英会误判失效、触发自动重启(关掉用户窗口)。
            note("\(r.displayName) HUD 无法识别(blank,可能模板不匹配)")
            return nil
        }
    }

    /// 仅在"原因"变化时记一条日志,避免后台每 120ms 刷屏。
    private func note(_ s: String) {
        if lastNote != s { lastNote = s; Log.track("未出状态:\(s)") }
    }
    private func clearNote() { lastNote = nil }

    private func updateIfChanged(_ mode: IMEMode) {
        if current != mode {
            current = mode; onChange?(mode)
            Log.track("状态变化 → \(mode.rawValue)(\(currentIMEName ?? "?"))")
            NotificationCenter.default.post(name: .imemoryStateChanged, object: nil)
        }
    }

    /// 启动事件驱动:Shift 单击 → 采样突发;输入法切换通知 → 状态置未知。
    public func start() {
        shiftMonitor.isSuppressed = { [weak self] in self?.suppressShift ?? false }
        shiftMonitor.onShiftTap = { [weak self] in
            DispatchQueue.global().async { self?.sampleBurst() }
        }
        shiftMonitor.start()
        imeSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { [weak self] _ in self?.imeSourceChanged() }
    }

    public func stop() {
        shiftMonitor.stop()
        if let o = imeSourceObserver { DistributedNotificationCenter.default().removeObserver(o) }
        imeSourceObserver = nil
    }

    /// 一次采样突发:~400ms 内最多读 5 次,拿到一帧成功识别即停(HUD 渲染/淡出有时差)。
    public func sampleBurst() {
        for _ in 0..<5 {
            if sampleOnce() != nil { return }
            usleep(80_000)
        }
    }

    private func imeSourceChanged() {
        if current != nil || currentIMEName != nil {
            current = nil
            Log.track("输入法切换 → 中/英重置为未知(待读取)")
            NotificationCenter.default.post(name: .imemoryStateChanged, object: nil)
        }
        lastIMEKey = nil
    }

    /// 冷启动锚定:不改变当前态地定出初始中/英(读不到则净零合成两次 Shift,中间读)。
    /// 合成期间置 suppress,避免被 ShiftMonitor 误当用户手势。
    public func anchorColdStart() {
        if sampleOnce() != nil { return }
        suppressShift = true
        defer { suppressShift = false }
        Switcher.postShiftToggle(); usleep(240_000); _ = sampleOnce()
        Switcher.postShiftToggle(); usleep(240_000); _ = sampleOnce()
    }

    /// 将输入法切换到 `target` 模式。通过 sampleOnce 读回确认,最多尝试 `maxAttempts` 次切换。
    /// 若已处于目标模式则直接返回 true,不做任何操作。
    @discardableResult
    public func setMode(_ target: IMEMode, maxAttempts: Int = 2) -> Bool {
        if current == target { return true }
        suppressShift = true
        defer { suppressShift = false }
        Log.track("请求切换 → \(target.rawValue)(当前 \(current?.rawValue ?? "未知"))")
        for i in 0..<maxAttempts {
            Switcher.postShiftToggle()
            usleep(220_000)                 // 等待 HUD 渲染完成
            if sampleOnce() == target {
                Log.track("切换成功(第 \(i + 1) 次)→ \(target.rawValue)")
                return true
            }
        }
        Log.track("切换失败,目标 \(target.rawValue),现为 \(current?.rawValue ?? "未知")")
        return current == target
    }
}
