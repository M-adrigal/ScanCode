import Foundation

enum PermissionRepair {
    static func resetAndRequest() {
        let status = resetScreenCapture()
        _ = CaptureService.requestPermission()
        CaptureService.openPermissionSettings()
        debugLog("permission: resetAndRequest status=\(status)")
    }

    @discardableResult
    static func resetScreenCapture() -> Int32 {
        guard let bundleID = Bundle.main.bundleIdentifier else { return -1 }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "ScreenCapture", bundleID]
        do {
            try process.run()
            process.waitUntilExit()
            debugLog("permission: tccutil reset \(bundleID) status=\(process.terminationStatus)")
            return process.terminationStatus
        } catch {
            debugLog("permission: tccutil failed \(error)")
            return -1
        }
    }
}
