import ApplicationServices

/// 用辅助功能(AX)判断当前是否有"可输入文本"的元素获得焦点。
/// 用途:进入 App 后,等真正有文本焦点了再合成 Shift 恢复中/英,
/// 避免在无焦点时空切换(失败)或乱切。需要辅助功能权限。
public enum FocusProbe {
    public static func hasTextFocus() -> Bool {
        guard let element = focusedElement() else { return false }
        var role: CFTypeRef?
        let roleStr = (AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success
                       ? role as? String : nil) ?? ""
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
        // 3) 其它角色:kAXValue 可写才算可编辑(排除只读对话区/网页内容)。
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success {
            return settable.boolValue
        }
        return false
    }

    /// 诊断:描述当前聚焦元素(role/是否可写/有无选区/属性数),用于排查焦点判定。
    public static func focusInfo() -> String {
        guard let element = focusedElement() else { return "无聚焦元素" }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        var names: CFArray?
        AXUIElementCopyAttributeNames(element, &names)
        let attrs = (names as? [String]) ?? []
        let hasSel = attrs.contains(kAXSelectedTextRangeAttribute as String)
        return "role=\((role as? String) ?? "?") 可写=\(settable.boolValue) 选区=\(hasSel) 属性数=\(attrs.count)"
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let raw = focused, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    /// 提示基于 Chromium/Electron 的 App(如 Claude)立刻启用辅助功能树。
    /// 否则它的焦点/文本属性是懒加载的,要等好几秒才能被读到。需辅助功能权限。
    public static func enableAccessibility(pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
}
