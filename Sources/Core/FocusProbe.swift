import ApplicationServices
import AppKit

/// 用辅助功能(AX)判断当前是否有"可输入文本"的元素获得焦点。
/// 用途:进入 App 后,等真正有文本焦点了再合成 Shift 恢复中/英,
/// 避免在无焦点时空切换(失败)或乱切。需要辅助功能权限。
public enum FocusProbe {
    /// - Parameter appPid: 前台 App 的 pid。systemWide 查不到聚焦元素时(如 Chrome 网页输入框),
    ///   回退查该 App 自身的 AX 焦点元素。
    public static func hasTextFocus(appPid: pid_t? = nil) -> Bool {
        guard let element = focusedElement(appPid: appPid) else { return false }
        return isTextLike(element)
    }

    /// 当前键盘焦点所属 App(bundleID/名称/pid),取 systemWide 焦点元素的属主进程。
    /// 覆盖层(Spotlight 等)抢焦点时也能正确报出其属主。取不到焦点返回 nil。
    public static func focusedApp() -> (bundleID: String, name: String, pid: pid_t)? {
        guard let el = systemWideFocused() else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(el, &pid) == .success, pid > 0,
              let app = NSRunningApplication(processIdentifier: pid),
              let bid = app.bundleIdentifier else { return nil }
        return (bid, app.localizedName ?? bid, pid)
    }

    /// 判断单个 AX 元素是否"可输入文本"。
    private static func isTextLike(_ element: AXUIElement) -> Bool {
        let roleStr = stringAttr(element, kAXRoleAttribute) ?? ""
        // 1) 明确的文本输入角色 → 是。
        if [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].map({ $0 as String }).contains(roleStr) {
            return true
        }
        // 2) 明显非文本的可写控件 → 否。
        let nonText: Set<String> = [
            kAXSliderRole as String, kAXIncrementorRole as String,
            kAXCheckBoxRole as String, kAXRadioButtonRole as String,
            kAXPopUpButtonRole as String, kAXMenuButtonRole as String,
        ]
        if nonText.contains(roleStr) { return false }
        // 3) 不透明自绘视图(如 JetBrains 终端 JediTerm):无角色、零 AX 属性,却有真实键盘焦点 → 视为可输入。
        //    标准非文本控件(按钮/滑块等)都带角色,不会落到这条。
        var names: CFArray?
        let attrCount = AXUIElementCopyAttributeNames(element, &names) == .success
            ? ((names as? [String])?.count ?? 0) : 0
        if roleStr.isEmpty && attrCount == 0 { return true }
        // 4) 其它角色:kAXValue 可写才算可编辑(排除只读对话区/网页正文)。
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success {
            return settable.boolValue
        }
        return false
    }

    /// 诊断:同时描述 systemWide 与 app 级聚焦元素,用于排查焦点判定(尤其 Chrome 网页)。
    public static func focusInfo(appPid: pid_t? = nil) -> String {
        let sys = systemWideFocused().map(describe) ?? "无"
        var appPart = "—"
        if let pid = appPid, let el = appFocused(pid: pid) { appPart = describe(el) }
        return "sys[\(sys)] app[\(appPart)]"
    }

    private static func describe(_ el: AXUIElement) -> String {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable)
        var names: CFArray?
        AXUIElementCopyAttributeNames(el, &names)
        let attrs = (names as? [String]) ?? []
        let hasSel = attrs.contains(kAXSelectedTextRangeAttribute as String)
        return "role=\(stringAttr(el, kAXRoleAttribute) ?? "?") 可写=\(settable.boolValue) 选区=\(hasSel) 属性数=\(attrs.count)"
    }

    private static func stringAttr(_ el: AXUIElement, _ key: String) -> String? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, key as CFString, &v) == .success ? (v as? String) : nil
    }

    /// 取聚焦元素:先 systemWide,查不到再回退到 App 自身(Chrome 网页内容 systemWide 常为空)。
    private static func focusedElement(appPid: pid_t? = nil) -> AXUIElement? {
        if let el = systemWideFocused() { return el }
        if let pid = appPid { return appFocused(pid: pid) }
        return nil
    }

    private static func systemWideFocused() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let raw = focused, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    private static func appFocused(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let raw = focused, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    /// 提示基于 Chromium/Electron 的 App(如 Chrome、Claude)立刻构建辅助功能树,
    /// 否则其焦点/文本属性懒加载、systemWide 也读不到网页内焦点。需辅助功能权限。
    ///  - AXManualAccessibility:Electron(Claude 等)的开关;
    ///  - AXEnhancedUserInterface:Chromium(Chrome)及 AppKit 应用的无障碍激活开关,
    ///    Chrome 网页输入框的焦点要靠它才会暴露给 AX。
    public static func enableAccessibility(pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }
}
