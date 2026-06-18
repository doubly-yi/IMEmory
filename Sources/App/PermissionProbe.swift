import CoreGraphics
import ApplicationServices
import AppKit

/// 探测并跳转两项关键权限:屏幕录制(读 HUD)、辅助功能(合成 Shift)。
enum PermissionProbe {
    static func hasScreenRecording() -> Bool { CGPreflightScreenCaptureAccess() }
    static func hasAccessibility() -> Bool { AXIsProcessTrusted() }

    static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }
    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }
    private static func open(_ s: String) {
        if let url = URL(string: s) { NSWorkspace.shared.open(url) }
    }
}
