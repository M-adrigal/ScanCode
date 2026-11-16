import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

enum CaptureService {
    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openPermissionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// 有些旧 TCC 记录会让 preflight 返回 true，但实际截屏失败；用一次极小捕获确认。
    static func verifyCaptureAccess() async -> Bool {
        guard hasPermission else { return false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            guard let display = content.displays.first else { return false }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = 64
            config.height = 64
            config.showsCursor = false
            _ = try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: config
            )
            return true
        } catch {
            debugLog("permission verify failed: \(error)")
            return false
        }
    }

    static func captureAllDisplays(screens: [NSScreen]) async throws -> [CapturedDisplay] {
        guard hasPermission else {
            throw ToolError.captureFailed("没有屏幕录制权限")
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
        } catch {
            throw ToolError.captureFailed(error.localizedDescription)
        }

        var captured: [CapturedDisplay] = []

        for display in content.displays {
            guard let screen = screen(for: display.displayID, in: screens) else { continue }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            // SCDisplay 的宽高在这台机器上是逻辑点；乘 backingScaleFactor 拿到 Retina 像素。
            let scale = max(1, Int(screen.backingScaleFactor.rounded()))
            config.width = display.width * scale
            config.height = display.height * scale
            config.showsCursor = false
            config.captureResolution = .best
            do {
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter, configuration: config
                )
                captured.append(CapturedDisplay(screen: screen, image: image))
            } catch {
                throw ToolError.captureFailed(error.localizedDescription)
            }
        }

        if captured.isEmpty {
            throw ToolError.captureFailed("没有可用的显示器")
        }
        return captured
    }

    private static func screen(for displayID: CGDirectDisplayID, in screens: [NSScreen]) -> NSScreen? {
        screens.first { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return number?.uint32Value == displayID
        }
    }
}
