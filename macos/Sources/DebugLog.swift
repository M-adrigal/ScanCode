import Foundation
import AppKit

private let logFileURL: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser
    let directory = base.appendingPathComponent("ScanCode", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("ScanCode.log")
}()

func debugLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[ScanCode] \(timestamp) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    FileHandle.standardError.write(data)
    if FileManager.default.fileExists(atPath: logFileURL.path) {
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    } else {
        try? data.write(to: logFileURL)
    }
}

func activateSelf() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    }
    NSApp.activate(ignoringOtherApps: true)
    let ok = NSRunningApplication.current.activate(options: [.activateAllWindows])
    debugLog("activateSelf result=\(ok)")
}
