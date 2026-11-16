import Foundation
import AppKit

let arguments = CommandLine.arguments

if arguments.contains("--selftest") {
    exit(SelfTest.run() ? 0 : 1)
}

if arguments.contains("--list-apps") {
    AppRegistry.printStatus()
    exit(0)
}

if arguments.contains("--reset-permission") {
    let bundleID = Bundle.main.bundleIdentifier ?? "-"
    let status = PermissionRepair.resetScreenCapture()
    let line = "bundleID=\(bundleID) tccutilStatus=\(status)\n"
    try? line.write(toFile: "/tmp/scancode-tcc.log", atomically: true, encoding: .utf8)
    print(line)
    exit(0)
}

if arguments.contains("--permission") {
    print("screenCapturePermission=\(CaptureService.hasPermission)")
    exit(0)
}

if arguments.contains("--capture-test") {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    Task { @MainActor in
        print("screenCapturePermission=\(CaptureService.hasPermission)")
        if !CaptureService.hasPermission {
            _ = CaptureService.requestPermission()
            print("permission requested; grant it in System Settings, then rerun --capture-test")
            exit(2)
        }
        do {
            let displays = try await CaptureService.captureAllDisplays(screens: NSScreen.screens)
            for (index, display) in displays.enumerated() {
                let path = "/tmp/scancode-capture-\(index).png"
                let ok = CaptureTest.writePNG(display.image, to: path)
                print("display[\(index)] \(display.image.width)x\(display.image.height) screen=\(display.screen.frame) written=\(ok) path=\(path)")
            }
            exit(0)
        } catch {
            print("capture failed: \(error.localizedDescription)")
            exit(1)
        }
    }
    app.run()
}

if arguments.contains("--dispatch-test") {
    exit(DispatchTest.run() ? 0 : 1)
}

if arguments.contains("--snapshot") {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("build/snapshots")
    SnapshotTools.run(outputDirectory: output)
    exit(0)
}

let multiDemo = arguments.contains("--multi-demo")
let autoDispatchDemo = arguments.contains("--demo-dispatch")
let demoMode = arguments.contains("--demo") || multiDemo || autoDispatchDemo
let integrationMode = arguments.contains("--integration-test")
let application = NSApplication.shared
let delegate = AppDelegate(demoMode: demoMode, multiDemo: multiDemo, autoDispatchDemo: autoDispatchDemo, integrationMode: integrationMode)
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
