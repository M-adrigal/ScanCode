import Foundation
import AppKit

enum Clipboard {
    @discardableResult
    static func write(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
