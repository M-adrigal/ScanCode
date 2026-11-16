import Foundation
import AppKit

final class ResultPanel: NSPanel {
    var onApp: ((AppDescriptor) -> Void)?
    var onCopy: (() -> Void)?
    var onClose: (() -> Void)?

    private let payload: QRPayload
    private let apps: [AppDescriptor]
    private let states: [String: AppState]
    private var appByTag: [Int: AppDescriptor] = [:]

    init(payload: QRPayload, apps: [AppDescriptor], states: [String: AppState]) {
        self.payload = payload
        self.apps = apps
        self.states = states
        let width: CGFloat = apps.isEmpty ? 480 : (apps.count == 1 ? 520 : 660)
        let height: CGFloat = apps.isEmpty ? 100 : 128
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        appearance = NSAppearance(named: .darkAqua)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let background = RoundedPanelView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        contentView = background
        buildContent(in: background)
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onClose?()
            return
        }
        super.keyDown(with: event)
    }

    func tapFirstAppForTesting() {
        guard let app = apps.first else { return }
        debugLog("panel: test tap \(app.id)")
        onApp?(app)
    }

    func show(anchor: NSRect, screen: NSScreen) {
        var origin = NSPoint(
            x: anchor.midX - frame.width / 2,
            y: anchor.minY - frame.height - 12
        )
        if origin.y < screen.visibleFrame.minY + 8 {
            origin.y = anchor.maxY + 12
        }
        let minX = screen.visibleFrame.minX + 8
        let maxX = screen.visibleFrame.maxX - frame.width - 8
        origin.x = min(max(origin.x, minX), maxX)
        let minY = screen.visibleFrame.minY + 8
        let maxY = screen.visibleFrame.maxY - frame.height - 8
        origin.y = min(max(origin.y, minY), maxY)
        setFrameOrigin(origin)

        activateSelf()
        makeKeyAndOrderFront(nil)
    }

    private func buildContent(in view: NSView) {
        let width = view.bounds.width
        let height = view.bounds.height
        let hasApps = !apps.isEmpty
        let headerY = height - 32

        let icon = NSImageView(frame: NSRect(x: 18, y: headerY, width: 24, height: 24))
        icon.image = NSImage(systemSymbolName: "qrcode", accessibilityDescription: "二维码")
        icon.contentTintColor = .secondaryLabelColor
        view.addSubview(icon)

        let title = NSTextField(labelWithString: payload.title)
        title.frame = NSRect(x: 50, y: height - 30, width: width - 160, height: 20)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .white
        view.addSubview(title)

        let subtitle = NSTextField(labelWithString: apps.isEmpty ? payload.raw : payload.summary)
        subtitle.frame = NSRect(x: 50, y: height - 50, width: width - 160, height: 18)
        subtitle.font = .systemFont(ofSize: 11.5)
        subtitle.textColor = NSColor(calibratedWhite: 0.66, alpha: 1)
        subtitle.cell?.lineBreakMode = .byTruncatingMiddle
        view.addSubview(subtitle)

        if let code = payload.extractCode {
            let badge = NSTextField(labelWithString: "提取码 \(code)")
            badge.frame = NSRect(x: width - 100, y: height - 34, width: 82, height: 24)
            badge.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
            badge.textColor = .white
            badge.alignment = .center
            badge.isBordered = false
            badge.isSelectable = true
            badge.drawsBackground = true
            badge.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.12)
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 7
            view.addSubview(badge)
        }

        let dividerY: CGFloat = hasApps ? 68 : 44
        let divider = NSBox(frame: NSRect(x: 18, y: dividerY, width: width - 36, height: 1))
        divider.boxType = .separator
        view.addSubview(divider)

        if hasApps {
            let recommended = recommendedApp()
            var x: CGFloat = 18
            let buttonWidth: CGFloat = apps.count == 1 ? 240 : 184
            for (index, app) in apps.enumerated() {
                let state = states[app.id] ?? .notInstalled
                let isRecommended = app.id == recommended?.id
                let button = makeAppButton(app: app, state: state, recommended: isRecommended, index: index)
                button.frame = NSRect(x: x, y: 16, width: buttonWidth, height: 38)
                if isRecommended {
                    let background = NSView(frame: button.frame)
                    background.wantsLayer = true
                    background.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
                    background.layer?.cornerRadius = 9
                    view.addSubview(background)
                }
                view.addSubview(button)
                appByTag[index] = app
                x += buttonWidth + 8
            }
        }

        let copyButton = NSButton(title: hasApps ? "复制" : "复制链接", target: self, action: #selector(copyTapped))
        copyButton.frame = hasApps
            ? NSRect(x: width - 140, y: 18, width: 56, height: 34)
            : NSRect(x: 18, y: 8, width: 104, height: 32)
        copyButton.bezelStyle = .rounded
        copyButton.font = .systemFont(ofSize: 12)
        view.addSubview(copyButton)

        let closeButton = NSButton(title: "关闭", target: self, action: #selector(closeTapped))
        closeButton.frame = hasApps
            ? NSRect(x: width - 76, y: 18, width: 52, height: 34)
            : NSRect(x: width - 70, y: 8, width: 52, height: 32)
        closeButton.bezelStyle = .rounded
        closeButton.font = .systemFont(ofSize: 12)
        view.addSubview(closeButton)
    }

    private func makeAppButton(app: AppDescriptor, state: AppState, recommended: Bool, index: Int) -> NSButton {
        let button = NSButton(title: "", target: self, action: #selector(appTapped(_:)))
        button.tag = index
        button.bezelStyle = .rounded
        button.image = AppRegistry.icon(app)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = .systemFont(ofSize: 12, weight: .medium)

        let statusText: String
        let statusColor: NSColor
        switch state {
        case .running:
            statusText = "● 运行中"
            statusColor = .systemGreen
        case .notRunning:
            statusText = "● 未打开"
            statusColor = NSColor(calibratedWhite: 0.62, alpha: 1)
        case .notInstalled:
            statusText = "● 未安装"
            statusColor = .systemRed
        }

        let titleColor: NSColor = .white
        let combined = NSMutableAttributedString(
            string: app.name + "  ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: titleColor
            ]
        )
        combined.append(NSAttributedString(
            string: statusText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 9.5),
                .foregroundColor: recommended ? NSColor.white.withAlphaComponent(0.8) : statusColor
            ]
        ))
        button.attributedTitle = combined

        if recommended {
            button.isBordered = false
            button.focusRingType = .none
            button.keyEquivalent = "\r"
        } else if index == 0 {
            button.keyEquivalent = "1"
        } else {
            button.keyEquivalent = "2"
        }

        if state != .running {
            button.alphaValue = 0.68
        }
        button.toolTip = tooltip(app: app, state: state)
        return button
    }

    private func tooltip(app: AppDescriptor, state: AppState) -> String {
        switch state {
        case .running:
            return "\(app.name) 运行中"
        case .notRunning:
            return "\(app.name) 未打开"
        case .notInstalled:
            return "未检测到 \(app.name)"
        }
    }

    private func recommendedApp() -> AppDescriptor? {
        switch payload.provider {
        case .baidu: return apps.first { $0.provider == .baidu }
        case .quark: return apps.first { $0.provider == .quark }
        default: return nil
        }
    }

    @objc private func appTapped(_ sender: NSButton) {
        guard let app = appByTag[sender.tag] else { return }
        debugLog("panel: tapped \(app.id)")
        onApp?(app)
    }

    @objc private func copyTapped() {
        onCopy?()
    }

    @objc private func closeTapped() {
        onClose?()
    }
}

private final class RoundedPanelView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        NSColor(calibratedWhite: 0.055, alpha: 0.97).setFill()
        path.fill()
        NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
