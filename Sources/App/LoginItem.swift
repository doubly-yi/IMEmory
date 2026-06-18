import ServiceManagement
import Foundation

/// 开机自启封装(SMAppService,macOS 13+)。
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("IMEmory 登录项设置失败:\(error)")
        }
    }
}
