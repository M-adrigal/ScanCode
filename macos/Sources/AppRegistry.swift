import Foundation
import AppKit

enum AppRegistry {
    static let baidu = AppDescriptor(
        id: "baidu",
        name: "百度网盘",
        bundleID: "com.baidu.netdisk",
        installURL: URL(string: "https://pan.baidu.com/download")!,
        provider: .baidu
    )

    static let quark = AppDescriptor(
        id: "quark",
        name: "夸克",
        bundleID: "com.quark.desktop",
        installURL: URL(string: "https://pan.quark.cn/")!,
        provider: .quark
    )

    static let all: [AppDescriptor] = [baidu, quark]

    static func appURL(_ app: AppDescriptor) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
    }

    static func runningApp(_ app: AppDescriptor) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first
    }

    static func state(_ app: AppDescriptor) -> AppState {
        guard appURL(app) != nil else { return .notInstalled }
        return runningApp(app) == nil ? .notRunning : .running
    }

    static func icon(_ app: AppDescriptor) -> NSImage {
        guard let url = appURL(app) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: app.name)
                ?? NSImage(size: NSSize(width: 20, height: 20))
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 22, height: 22)
        return image
    }

    /// 运行中的客户端可能只剩菜单栏图标、没有窗口；用 open -b 让客户端自己重开主窗口。
    static func reopen(_ app: AppDescriptor) {
        guard runningApp(app) != nil else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", app.bundleID]
        do {
            try process.run()
            debugLog("reopen: \(app.id)")
        } catch {
            debugLog("reopen: failed \(error)")
        }
    }

    @discardableResult
    static func activate(_ app: NSRunningApplication) -> Bool {
        app.unhide()
        let result = app.activate(options: [.activateAllWindows])
        let target = app.localizedName ?? app.bundleIdentifier ?? "?"
        debugLog("activate: \(target) result=\(result)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "-"
            debugLog("activate: frontmost=\(front) expected=\(target)")
        }
        return result
    }

    static func printStatus() {
        for app in all {
            let state = state(app).rawValue
            let path = appURL(app)?.path ?? "-"
            let pid = runningApp(app)?.processIdentifier ?? 0
            print("\(app.id)\t\(app.name)\t\(state)\tpid=\(pid)\t\(path)")
        }
    }
}
