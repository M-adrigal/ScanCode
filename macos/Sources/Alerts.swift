import Foundation
import AppKit

enum Alerts {
    static func show(
        title: String,
        message: String,
        buttons: [String],
        style: NSAlert.Style = .informational,
        completion: ((Int) -> Void)? = nil
    ) {
        activateSelf()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.icon = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: nil)
        for title in buttons {
            alert.addButton(withTitle: title)
        }
        let response = alert.runModal()
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        completion?(max(0, index))
    }

    static func permission() {
        show(
            title: "需要屏幕录制权限",
            message: "在系统设置中允许「扫码助手」使用屏幕录制。",
            buttons: ["打开系统设置", "取消"],
            style: .warning
        ) { index in
            if index == 0 { CaptureService.openPermissionSettings() }
        }
    }

    static func appNotRunning(_ name: String) {
        show(
            title: "\(name)未打开",
            message: "先打开\(name)，再试一次。",
            buttons: ["好"]
        )
    }

    static func appNotInstalled(_ name: String, installURL: URL) {
        show(
            title: "未检测到\(name)",
            message: "先安装再使用。",
            buttons: ["去下载", "取消"]
        ) { index in
            if index == 0 { NSWorkspace.shared.open(installURL) }
        }
    }

    static func noQR(retry: @escaping () -> Void) {
        show(
            title: "没识别到二维码",
            message: "换个区域再试一次。",
            buttons: ["重新框选", "取消"]
        ) { index in
            if index == 0 { retry() }
        }
    }

    static func dispatchFailed(_ message: String) {
        show(title: "操作失败", message: message, buttons: ["好"], style: .warning)
    }

    static func captureFailed(_ message: String, repair: @escaping () -> Void) {
        show(
            title: "无法截取屏幕",
            message: message,
            buttons: ["修复权限", "取消"],
            style: .warning
        ) { index in
            if index == 0 { repair() }
        }
    }
}
