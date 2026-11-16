import Foundation
import AppKit

enum SnapshotTools {
    static func run(outputDirectory: URL) {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let size = NSSize(width: 1200, height: 760)
        if let (image, rect) = DemoScene.make(size: size) {
            let overlay = SelectionView(frame: NSRect(origin: .zero, size: size), image: image)
            overlay.setSelectionForSnapshot(rect)
            render(overlay, size: size, to: outputDirectory.appendingPathComponent("overlay.png"), dark: true)
        } else {
            debugLog("snapshot: demo scene failed")
        }

        let payload = ContentParser.parse("https://pan.baidu.com/s/1QrDemo8xK?pwd=8xk2")
        let notRunningStates: [String: AppState] = ["baidu": .notRunning]
        let panel = ResultPanel(payload: payload, apps: [AppRegistry.baidu], states: notRunningStates)
        if let view = panel.contentView {
            view.frame = NSRect(origin: .zero, size: panel.frame.size)
            render(view, size: panel.frame.size,
                   to: outputDirectory.appendingPathComponent("panel-not-running.png"), dark: true)
        }

        let runningStates: [String: AppState] = ["baidu": .running]
        let runningPanel = ResultPanel(payload: payload, apps: [AppRegistry.baidu], states: runningStates)
        if let view = runningPanel.contentView {
            view.frame = NSRect(origin: .zero, size: runningPanel.frame.size)
            render(view, size: runningPanel.frame.size,
                   to: outputDirectory.appendingPathComponent("panel-running.png"), dark: true)
        }

        let webPayload = ContentParser.parse("https://example.com/hello")
        let webPanel = ResultPanel(payload: webPayload, apps: [], states: [:])
        if let view = webPanel.contentView {
            view.frame = NSRect(origin: .zero, size: webPanel.frame.size)
            render(view, size: webPanel.frame.size,
                   to: outputDirectory.appendingPathComponent("panel-web.png"), dark: true)
        }
    }

    private static func render(_ view: NSView, size: NSSize, to url: URL, dark: Bool) {
        if dark {
            view.appearance = NSAppearance(named: .darkAqua)
        }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: NSRect(origin: .zero, size: size)) else {
            debugLog("snapshot: no bitmap for \(url.lastPathComponent)")
            return
        }
        view.cacheDisplay(in: NSRect(origin: .zero, size: size), to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            debugLog("snapshot: no png for \(url.lastPathComponent)")
            return
        }
        do {
            try data.write(to: url)
            debugLog("snapshot: wrote \(url.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
        } catch {
            debugLog("snapshot: write failed \(error)")
        }
    }
}
