import Foundation
import AppKit

final class SelectionView: NSView {
    var onSelect: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private let frozenImage: CGImage
    private var startPoint: NSPoint?
    private var selectionRect: NSRect = .zero
    private var awaitingConfirmation = false
    private var confirmButtonRect: NSRect = .zero
    private var hotspots: [QRHotspot] = []
    var onHotspotPick: ((QRHotspot) -> Void)?

    init(frame: NSRect, image: CGImage) {
        self.frozenImage = image
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current else { return }
        context.imageInterpolation = .high

        NSImage(cgImage: frozenImage, size: bounds.size).draw(in: bounds)

        let dimPath = NSBezierPath(rect: bounds)
        if isValid(selectionRect) {
            dimPath.append(NSBezierPath(rect: selectionRect))
        }
        dimPath.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.56).setFill()
        dimPath.fill()

        guard isValid(selectionRect) else { return }

        let border = NSBezierPath(rect: selectionRect)
        border.lineWidth = 2
        NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1).setStroke()
        border.stroke()

        let handleLength: CGFloat = 12
        let handlePath = NSBezierPath()
        let points: [(NSPoint, NSPoint, NSPoint)] = [
            (NSPoint(x: selectionRect.minX, y: selectionRect.minY + handleLength),
             NSPoint(x: selectionRect.minX, y: selectionRect.minY),
             NSPoint(x: selectionRect.minX + handleLength, y: selectionRect.minY)),
            (NSPoint(x: selectionRect.maxX - handleLength, y: selectionRect.minY),
             NSPoint(x: selectionRect.maxX, y: selectionRect.minY),
             NSPoint(x: selectionRect.maxX, y: selectionRect.minY + handleLength)),
            (NSPoint(x: selectionRect.maxX, y: selectionRect.maxY - handleLength),
             NSPoint(x: selectionRect.maxX, y: selectionRect.maxY),
             NSPoint(x: selectionRect.maxX - handleLength, y: selectionRect.maxY)),
            (NSPoint(x: selectionRect.minX + handleLength, y: selectionRect.maxY),
             NSPoint(x: selectionRect.minX, y: selectionRect.maxY),
             NSPoint(x: selectionRect.minX, y: selectionRect.maxY - handleLength))
        ]
        for (a, b, c) in points {
            handlePath.move(to: a)
            handlePath.line(to: b)
            handlePath.line(to: c)
        }
        handlePath.lineWidth = 2.5
        NSColor.white.setStroke()
        handlePath.stroke()

        let sizeText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = sizeText.size(withAttributes: attributes)
        let badge = NSRect(
            x: selectionRect.minX,
            y: selectionRect.maxY + 8,
            width: textSize.width + 16,
            height: 22
        )
        NSColor(calibratedWhite: 0.06, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 6, yRadius: 6).fill()
        sizeText.draw(
            at: NSPoint(x: badge.minX + 8, y: badge.minY + 5),
            withAttributes: attributes
        )

        if !hotspots.isEmpty {
            drawHotspots()
        } else if awaitingConfirmation {
            drawConfirmButton()
        }

        let hintText: String
        if !hotspots.isEmpty {
            hintText = "选择要识别的二维码　·　Esc 取消"
        } else if awaitingConfirmation {
            hintText = "Esc 取消"
        } else {
            hintText = "拖动框选二维码　·　Esc 取消"
        }
        let hint = hintText as NSString
        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let hintSize = hint.size(withAttributes: hintAttributes)
        let hintRect = NSRect(
            x: bounds.midX - hintSize.width / 2 - 18,
            y: 26,
            width: hintSize.width + 36,
            height: 34
        )
        NSColor(calibratedWhite: 0.04, alpha: 0.84).setFill()
        let hintPath = NSBezierPath(roundedRect: hintRect, xRadius: 17, yRadius: 17)
        hintPath.fill()
        NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
        hintPath.lineWidth = 1
        hintPath.stroke()
        hint.draw(
            at: NSPoint(x: hintRect.minX + 18, y: hintRect.minY + 10),
            withAttributes: hintAttributes
        )
    }

    private func drawHotspots() {
        let bannerText = "发现 \(hotspots.count) 个二维码，点击一个继续" as NSString
        let bannerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let bannerSize = bannerText.size(withAttributes: bannerAttrs)
        let banner = NSRect(
            x: bounds.midX - bannerSize.width / 2 - 18,
            y: bounds.maxY - 64,
            width: bannerSize.width + 36,
            height: 34
        )
        NSColor(calibratedWhite: 0.04, alpha: 0.94).setFill()
        NSBezierPath(roundedRect: banner, xRadius: 10, yRadius: 10).fill()
        bannerText.draw(
            at: NSPoint(x: banner.midX - bannerSize.width / 2,
                        y: banner.midY - bannerSize.height / 2),
            withAttributes: bannerAttrs
        )

        for (index, spot) in hotspots.enumerated() {
            let path = NSBezierPath(roundedRect: spot.rect, xRadius: 6, yRadius: 6)
            NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 2.5
            path.stroke()

            let badge = NSRect(x: spot.rect.minX, y: spot.rect.maxY + 6, width: 24, height: 22)
            NSColor(calibratedWhite: 0.04, alpha: 0.94).setFill()
            NSBezierPath(roundedRect: badge, xRadius: 6, yRadius: 6).fill()
            let number = "\(index + 1)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let size = number.size(withAttributes: attrs)
            number.draw(at: NSPoint(x: badge.midX - size.width / 2,
                                    y: badge.midY - size.height / 2),
                        withAttributes: attrs)
        }
    }

    func showHotspots(_ spots: [QRHotspot]) {
        hotspots = spots
        awaitingConfirmation = false
        needsDisplay = true
    }

    private func drawConfirmButton() {
        let width: CGFloat = 132
        let height: CGFloat = 34
        var x = selectionRect.maxX - width
        var y = selectionRect.minY - height - 12
        if y < 44 {
            y = selectionRect.maxY + 12
        }
        x = min(max(x, 12), bounds.width - width - 12)
        y = min(max(y, 12), bounds.height - height - 12)
        confirmButtonRect = NSRect(x: x, y: y, width: width, height: height)

        let path = NSBezierPath(roundedRect: confirmButtonRect, xRadius: 9, yRadius: 9)
        NSColor.controlAccentColor.setFill()
        path.fill()

        let title = "解析二维码" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(
                x: confirmButtonRect.midX - size.width / 2,
                y: confirmButtonRect.midY - size.height / 2
            ),
            withAttributes: attributes
        )
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if !hotspots.isEmpty {
            for spot in hotspots {
                let badge = NSRect(x: spot.rect.minX - 2, y: spot.rect.maxY,
                                   width: 28, height: 30)
                if spot.rect.insetBy(dx: -4, dy: -4).contains(point) || badge.contains(point) {
                    onHotspotPick?(spot)
                    return
                }
            }
            return
        }

        if awaitingConfirmation {
            if confirmButtonRect.contains(point) {
                onSelect?(selectionRect)
                return
            }
            // 点击按钮之外：重新框选
            awaitingConfirmation = false
            hotspots = []
            selectionRect = .zero
        }

        startPoint = point
        selectionRect = NSRect(origin: point, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        awaitingConfirmation = false
        let point = convert(event.locationInWindow, from: nil)
        selectionRect = normalizedRect(from: startPoint, to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        selectionRect = normalizedRect(from: startPoint, to: point)
        self.startPoint = nil
        needsDisplay = true

        if isValid(selectionRect) {
            awaitingConfirmation = true
            needsDisplay = true
        } else {
            onCancel?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onCancel?()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
            if awaitingConfirmation, isValid(selectionRect) {
                onSelect?(selectionRect)
            }
            return
        }
        super.keyDown(with: event)
    }

    func setSelectionForSnapshot(_ rect: NSRect) {
        selectionRect = rect
        awaitingConfirmation = true
        needsDisplay = true
    }

    func setAutoSelection(_ rect: NSRect, confirmAfter delay: TimeInterval) {
        debugLog("overlay: auto select \(rect)")
        selectionRect = rect
        hotspots = []
        awaitingConfirmation = true
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.awaitingConfirmation, self.isValid(self.selectionRect) else { return }
            self.onSelect?(self.selectionRect)
        }
    }

    private func normalizedRect(from a: NSPoint, to b: NSPoint) -> NSRect {
        NSRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        ).intersection(bounds)
    }

    private func isValid(_ rect: NSRect) -> Bool {
        rect.width >= 8 && rect.height >= 8
    }
}

final class OverlayWindow: NSWindow {
    let display: CapturedDisplay
    let selectionView: SelectionView
    var onSelect: ((CapturedDisplay, NSRect) -> Void)?
    var onHotspot: ((CapturedDisplay, QRHotspot) -> Void)?
    var onCancel: (() -> Void)?

    init(display: CapturedDisplay) {
        self.display = display
        let frame = display.screen.frame
        self.selectionView = SelectionView(
            frame: NSRect(origin: .zero, size: frame.size),
            image: display.image
        )
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        contentView = selectionView

        selectionView.onSelect = { [weak self] rect in
            guard let self else { return }
            self.onSelect?(self.display, rect)
        }
        selectionView.onCancel = { [weak self] in
            self?.onCancel?()
        }
        selectionView.onHotspotPick = { [weak self] spot in
            guard let self else { return }
            self.onHotspot?(self.display, spot)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // 不让 AppKit 把无边框窗口挤到菜单栏/Dock 下方，保证全屏遮罩完整。
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class OverlayController {
    private var windows: [OverlayWindow] = []
    var onSelect: ((CapturedDisplay, NSRect) -> Void)?
    var onHotspot: ((CapturedDisplay, QRHotspot) -> Void)?
    var onCancel: (() -> Void)?

    func present(_ displays: [CapturedDisplay], autoSelect: (NSScreen, NSRect)? = nil) {
        close()

        for display in displays {
            let window = OverlayWindow(display: display)
            window.onSelect = { [weak self] display, rect in
                self?.onSelect?(display, rect)
            }
            window.onCancel = { [weak self] in
                self?.onCancel?()
            }
            window.onHotspot = { [weak self] display, spot in
                self?.onHotspot?(display, spot)
            }
            windows.append(window)
        }

        debugLog("overlay: displays=\(displays.count) windows=\(windows.count)")
        activateSelf()

        for window in windows {
            window.orderFrontRegardless()
            debugLog("overlay: frame=\(window.frame) visible=\(window.isVisible) level=\(window.level.rawValue)")
        }
        windows.first?.makeKey()
        if let first = windows.first {
            first.makeFirstResponder(first.selectionView)
        }

        if let autoSelect,
           let window = windows.first(where: { $0.display.screen === autoSelect.0 }) {
            window.selectionView.setAutoSelection(autoSelect.1, confirmAfter: 1.0)
        }
    }

    func showHotspots(_ spots: [QRHotspot], on display: CapturedDisplay) {
        windows.first { $0.display.screen === display.screen }?
            .selectionView.showHotspots(spots)
    }

    func close() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}
