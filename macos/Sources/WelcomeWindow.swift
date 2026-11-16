import Foundation
import AppKit

final class WelcomeWindow: NSWindow, NSWindowDelegate {
    private let onStart: () -> Void
    private let onPermission: () -> Void
    private let onQuit: () -> Void
    private var baiduStatus: NSTextField!
    private var quarkStatus: NSTextField!
    private var permissionButton: NSButton!

    init(
        onStart: @escaping () -> Void,
        onPermission: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onPermission = onPermission
        self.onQuit = onQuit
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = "扫码助手"
        titleVisibility = .hidden
        isReleasedWhenClosed = false
        delegate = self
        buildContent()
        center()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func windowDidBecomeKey(_ notification: Notification) {
        refresh()
    }

    func refresh() {
        baiduStatus?.attributedStringValue = statusLine(for: AppRegistry.baidu)
        quarkStatus?.attributedStringValue = statusLine(for: AppRegistry.quark)

        if CaptureService.hasPermission {
            permissionButton?.title = "屏幕录制已授权"
            permissionButton?.contentTintColor = .secondaryLabelColor
            permissionButton?.isEnabled = false
        } else {
            permissionButton?.title = "屏幕录制未授权 · 打开系统设置"
            permissionButton?.contentTintColor = .controlAccentColor
            permissionButton?.isEnabled = true
        }
    }

    private func buildContent() {
        guard let content = contentView else { return }

        let icon = NSImageView(frame: NSRect(x: 212, y: 340, width: 96, height: 96))
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            icon.image = image
        } else {
            icon.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "扫码助手")
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        content.addSubview(icon)

        let heading = NSTextField(labelWithString: "扫码助手")
        heading.frame = NSRect(x: 36, y: 300, width: 448, height: 30)
        heading.font = .systemFont(ofSize: 24, weight: .semibold)
        heading.alignment = .center
        heading.textColor = .labelColor
        content.addSubview(heading)

        let subtitle = NSTextField(wrappingLabelWithString: "框选屏幕上的二维码，\n在已打开的应用里继续。")
        subtitle.frame = NSRect(x: 36, y: 258, width: 448, height: 36)
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        content.addSubview(subtitle)

        let card = NSView(frame: NSRect(x: 36, y: 126, width: 448, height: 124))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 12
        content.addSubview(card)

        let cardTitle = NSTextField(labelWithString: "应用")
        cardTitle.frame = NSRect(x: 18, y: 94, width: 200, height: 18)
        cardTitle.font = .systemFont(ofSize: 11, weight: .medium)
        cardTitle.textColor = .secondaryLabelColor
        card.addSubview(cardTitle)

        baiduStatus = NSTextField(labelWithString: "")
        baiduStatus.frame = NSRect(x: 18, y: 64, width: 412, height: 20)
        card.addSubview(baiduStatus)

        quarkStatus = NSTextField(labelWithString: "")
        quarkStatus.frame = NSRect(x: 18, y: 38, width: 412, height: 20)
        card.addSubview(quarkStatus)

        permissionButton = NSButton(title: "屏幕录制未授权 · 打开系统设置", target: self, action: #selector(permissionTapped))
        permissionButton.frame = NSRect(x: 18, y: 8, width: 412, height: 20)
        permissionButton.isBordered = false
        permissionButton.alignment = .left
        permissionButton.contentTintColor = .controlAccentColor
        permissionButton.font = .systemFont(ofSize: 12)
        card.addSubview(permissionButton)

        let start = NSButton(title: "开始识别二维码", target: self, action: #selector(startTapped))
        start.frame = NSRect(x: 110, y: 64, width: 300, height: 44)
        start.bezelStyle = .rounded
        start.keyEquivalent = "\r"
        start.font = .systemFont(ofSize: 14, weight: .semibold)
        content.addSubview(start)

        let quit = NSButton(title: "退出", target: self, action: #selector(quitTapped))
        quit.frame = NSRect(x: 36, y: 24, width: 60, height: 22)
        quit.isBordered = false
        quit.contentTintColor = .secondaryLabelColor
        quit.font = .systemFont(ofSize: 11)
        content.addSubview(quit)

        let footer = NSTextField(labelWithString: "v0.1.6")
        footer.frame = NSRect(x: 424, y: 26, width: 60, height: 16)
        footer.font = .systemFont(ofSize: 10)
        footer.textColor = .tertiaryLabelColor
        footer.alignment = .right
        content.addSubview(footer)

        refresh()
    }

    private func statusLine(for app: AppDescriptor) -> NSAttributedString {
        let state = AppRegistry.state(app)
        let dot: String
        let detail: String
        let color: NSColor
        switch state {
        case .running:
            dot = "●"
            detail = "运行中"
            color = .systemGreen
        case .notRunning:
            dot = "●"
            detail = "未打开"
            color = .secondaryLabelColor
        case .notInstalled:
            dot = "●"
            detail = "未安装"
            color = .systemRed
        }

        let result = NSMutableAttributedString(
            string: dot + " ",
            attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: color]
        )
        result.append(NSAttributedString(
            string: app.name,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        ))
        result.append(NSAttributedString(
            string: "   " + detail,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        return result
    }

    @objc private func startTapped() { onStart() }
    @objc private func permissionTapped() { onPermission() }
    @objc private func quitTapped() { onQuit() }
}
