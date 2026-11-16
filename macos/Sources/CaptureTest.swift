import Foundation
import AppKit

enum CaptureTest {
    static func writePNG(_ image: CGImage, to path: String) -> Bool {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            debugLog("capture-test write failed: \(error)")
            return false
        }
    }
}
