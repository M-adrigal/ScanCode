import Foundation
import AppKit

enum HUD {
    private static var panel: NSPanel?
    private static var dismissWork: DispatchWorkItem?

    static func hide() {
        dismissWork?.cancel()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    static func show(_ message: String, on screen: NSScreen, isError: Bool = false) {
        dismissWork?.cancel()
        panel?.orderOut(nil)
        panel?.close()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = (message as NSString).size(withAttributes: attributes)
        let width = min(max(textSize.width + 44, 320), 620)
        let height: CGFloat = 58

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = HUDView(frame: NSRect(x: 0, y: 0, width: width, height: height), isError: isError)
        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 22, y: 18, width: width - 44, height: 22)
        label.font = .systemFont(ofSize: 12.5, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.cell?.lineBreakMode = .byTruncatingTail
        view.addSubview(label)
        panel.contentView = view

        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - width / 2,
            y: visible.minY + 26
        ))
        panel.orderFrontRegardless()

        HUD.panel = panel
        let item = DispatchWorkItem { [weak panel] in
            panel?.orderOut(nil)
            panel?.close()
        }
        dismissWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: item)
    }
}

private final class HUDView: NSView {
    private let isError: Bool

    init(frame: NSRect, isError: Bool) {
        self.isError = isError
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14)
        NSColor(calibratedWhite: 0.055, alpha: 0.96).setFill()
        path.fill()
        (isError ? NSColor.systemRed.withAlphaComponent(0.7) : NSColor(calibratedWhite: 1, alpha: 0.12))
            .setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
