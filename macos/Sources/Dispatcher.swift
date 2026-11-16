import Foundation
import AppKit

enum Dispatcher {
    /// v1 只允许激活已运行的 App，绝不启动目标应用。
    static func dispatch(_ payload: QRPayload, to app: AppDescriptor) throws -> String {
        switch AppRegistry.state(app) {
        case .notInstalled:
            throw ToolError.appNotInstalled(app.name)
        case .notRunning:
            throw ToolError.appNotRunning(app.name)
        case .running:
            break
        }

        guard let running = AppRegistry.runningApp(app) else {
            throw ToolError.appNotRunning(app.name)
        }

        switch app.provider {
        case .baidu:
            guard Clipboard.write(text: payload.clipboardText) else {
                throw ToolError.dispatchFailed("无法写入剪贴板")
            }
            debugLog("dispatch: baidu copy+reopen")
            AppRegistry.reopen(app)
            AppRegistry.activate(running)
            return "已复制，已唤起百度网盘"

        case .quark:
            guard let url = payload.url else {
                throw ToolError.noURL
            }
            guard let appURL = AppRegistry.appURL(app) else {
                throw ToolError.appNotInstalled(app.name)
            }
            debugLog("dispatch: quark reopen+open url")
            AppRegistry.reopen(app)
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error {
                    debugLog("dispatch: quark open error \(error.localizedDescription)")
                }
            }
            AppRegistry.activate(running)
            return "已在夸克打开"

        case .web, .text:
            throw ToolError.dispatchFailed("该二维码不需要唤起网盘应用")
        }
    }
}
