import Foundation
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let demoMode: Bool
    private let multiDemo: Bool
    private let autoDispatchDemo: Bool
    private var demoPass = 0
    private let integrationMode: Bool
    private let hotkey = HotkeyCenter()
    private var statusItem: NSStatusItem?
    private var overlayController: OverlayController?
    private var resultPanel: ResultPanel?
    private var welcomeWindow: WelcomeWindow?
    private var isCapturing = false
    private var didRequestPermission = false
    private var didVerifyCapture = false
    private var lastScreen: NSScreen?

    init(demoMode: Bool, multiDemo: Bool = false, autoDispatchDemo: Bool = false, integrationMode: Bool = false) {
        self.demoMode = demoMode
        self.multiDemo = multiDemo
        self.autoDispatchDemo = autoDispatchDemo
        self.integrationMode = integrationMode
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        hotkey.onHotkey = { [weak self] in
            self?.hotkeyPressed()
        }
        let status = hotkey.register()
        debugLog("hotkey register status=\(status)")
        if status != noErr {
            statusItem?.button?.toolTip = "快捷键冲突：⌃⌥Q 已被占用"
            statusItem?.button?.title = "!"
        }

        if demoMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.runDemo()
            }
        } else if integrationMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.runIntegrationTest()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.showWelcome()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.unregister()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "扫码助手") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "扫码"
            }
            button.toolTip = "扫码助手 · ⌃⌥Q"
        }

        let menu = NSMenu()
        menu.addItem(menuItem("打开主界面", action: #selector(showWelcomeAction)))
        menu.addItem(.separator())
        menu.addItem(menuItem("框选识别  ⌃⌥Q", action: #selector(startCapture)))
        menu.addItem(menuItem("从剪贴板识别", action: #selector(decodeClipboard)))
        menu.addItem(.separator())
        menu.addItem(menuItem("屏幕录制权限…", action: #selector(showPermissionStatus)))
        menu.addItem(menuItem("修复屏幕录制权限…", action: #selector(repairPermissionAction)))
        menu.addItem(menuItem("关于扫码助手", action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(menuItem("退出", action: #selector(quit)))
        item.menu = menu
        statusItem = item
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func hotkeyPressed() {
        if overlayController != nil {
            cancelFlow()
            return
        }
        if resultPanel != nil {
            closeResult()
            startCapture()
            return
        }
        startCapture()
    }

    @objc private func startCapture() {
        guard !isCapturing else { return }
        welcomeWindow?.orderOut(nil)
        HUD.hide()
        if demoMode {
            runDemo()
            return
        }
        if !CaptureService.hasPermission {
            Alerts.permission()
            return
        }

        isCapturing = true
        Task { @MainActor in
            do {
                let displays = try await CaptureService.captureAllDisplays(screens: NSScreen.screens)
                self.presentOverlay(displays)
            } catch {
                self.isCapturing = false
                Alerts.captureFailed(error.localizedDescription) { [weak self] in
                    self?.repairPermissionFlow()
                }
            }
        }
    }

    private func presentOverlay(_ displays: [CapturedDisplay], autoSelect: (NSScreen, NSRect)? = nil) {
        closeResult()
        overlayController?.close()

        let controller = OverlayController()
        controller.onSelect = { [weak self] display, rect in
            self?.handleSelection(display: display, rect: rect)
        }
        controller.onHotspot = { [weak self] display, spot in
            self?.finishSelection(display: display, payload: spot.payload, viewRect: spot.rect)
        }
        controller.onCancel = { [weak self] in
            DispatchQueue.main.async {
                self?.overlayController?.close()
                self?.overlayController = nil
                self?.isCapturing = false
            }
        }
        overlayController = controller
        controller.present(displays, autoSelect: autoSelect)
    }

    private func handleSelection(display: CapturedDisplay, rect: NSRect) {
        debugLog("selection: \(rect)")
        lastScreen = display.screen
        let image = display.image
        let screenFrame = display.screen.frame
        guard screenFrame.width > 0, screenFrame.height > 0 else { return }

        let sx = CGFloat(image.width) / screenFrame.width
        let sy = CGFloat(image.height) / screenFrame.height
        var crop = NSRect(
            x: rect.minX * sx,
            y: (screenFrame.height - rect.maxY) * sy,
            width: rect.width * sx,
            height: rect.height * sy
        ).integral

        let padX = 12 * sx
        let padY = 12 * sy
        crop = crop.insetBy(dx: -padX, dy: -padY)
        crop = crop.intersection(NSRect(x: 0, y: 0, width: image.width, height: image.height))

        guard crop.width > 4, crop.height > 4, let cropped = image.cropping(to: crop) else {
            closeOverlayAndShowNoQR()
            return
        }

        let results = QRDecoder.decode(cropped)
        guard !results.isEmpty else {
            closeOverlayAndShowNoQR()
            return
        }

        if results.count > 1 {
            // 多码时回到遮罩上，由用户点选具体二维码。
            let spots = makeHotspots(in: display, selection: rect)
            if spots.count > 1 {
                overlayController?.showHotspots(spots, on: display)
                debugLog("selection: multiple QR codes \(spots.count)")
                return
            }
        }

        let payload = ContentParser.parse(results[0].raw)
        finishSelection(display: display, payload: payload, viewRect: rect)
    }

    private func makeHotspots(in display: CapturedDisplay, selection: NSRect) -> [QRHotspot] {
        let screenFrame = display.screen.frame
        let width = screenFrame.width
        let height = screenFrame.height
        var spots: [QRHotspot] = []
        var seen = Set<String>()

        for code in QRDecoder.decode(display.image) {
            let box = NSRect(
                x: code.bounds.minX * width,
                y: code.bounds.minY * height,
                width: code.bounds.width * width,
                height: code.bounds.height * height
            )
            guard box.intersects(selection.insetBy(dx: -8, dy: -8)) else { continue }
            guard seen.insert(code.raw).inserted else { continue }
            spots.append(QRHotspot(rect: box, payload: ContentParser.parse(code.raw)))
        }
        return spots
    }

    private func finishSelection(display: CapturedDisplay, payload: QRPayload, viewRect: NSRect) {
        let screen = display.screen
        let screenFrame = screen.frame
        let anchor = NSRect(
            x: screenFrame.minX + viewRect.minX,
            y: screenFrame.minY + viewRect.minY,
            width: viewRect.width,
            height: viewRect.height
        )
        // 不要在 SelectionView 的回调栈里关窗口。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // 先让结果条成为 key window，再关遮罩，避免第一次点击只激活窗口。
            self.showResult(payload, anchor: anchor, screen: screen)
            self.overlayController?.close()
            self.overlayController = nil
            self.isCapturing = false
        }
    }

    private func closeOverlayAndShowNoQR() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.overlayController?.close()
            self.overlayController = nil
            self.isCapturing = false
            Alerts.noQR { [weak self] in self?.startCapture() }
        }
    }

    private func showResult(_ payload: QRPayload, anchor: NSRect, screen: NSScreen) {
        closeResult()
        lastScreen = screen

        let candidates: [AppDescriptor]
        switch payload.provider {
        case .baidu: candidates = [AppRegistry.baidu]
        case .quark: candidates = [AppRegistry.quark]
        case .web, .text: candidates = []
        }

        let states = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, AppRegistry.state($0)) })
        let panel = ResultPanel(payload: payload, apps: candidates, states: states)
        panel.onApp = { [weak self] app in
            self?.dispatch(payload, to: app, screen: screen)
        }
        panel.onCopy = {
            Clipboard.write(text: payload.raw)
            HUD.show("已复制", on: screen)
        }
        panel.onClose = { [weak self] in
            self?.closeResult()
        }
        resultPanel = panel
        debugLog("result: showing panel")
        panel.show(anchor: anchor, screen: screen)
        debugLog("result: panel shown")

        if autoDispatchDemo {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, let panel = self.resultPanel else { return }
                panel.tapFirstAppForTesting()
                if self.demoPass == 0 {
                    self.demoPass = 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.runDemo()
                    }
                }
            }
        }
    }

    private func dispatch(_ payload: QRPayload, to app: AppDescriptor, screen: NSScreen) {
        do {
            let message = try Dispatcher.dispatch(payload, to: app)
            closeResult()
            HUD.show(message, on: screen)
        } catch let error as ToolError {
            switch error {
            case .appNotRunning(let name):
                Alerts.appNotRunning(name)
            case .appNotInstalled(let name):
                Alerts.appNotInstalled(name, installURL: app.installURL)
            default:
                Alerts.dispatchFailed(error.localizedDescription)
            }
        } catch {
            Alerts.dispatchFailed(error.localizedDescription)
        }
    }

    @objc private func decodeClipboard() {
        let pasteboard = NSPasteboard.general
        let screen = lastScreen ?? NSScreen.main ?? NSScreen.screens[0]

        if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = objects.first,
           let cg = cgImage(from: image) {
            let results = QRDecoder.decode(cg)
            if let first = results.first {
                let payload = ContentParser.parse(first.raw)
                let anchor = NSRect(
                    x: screen.frame.midX - 120,
                    y: screen.frame.midY - 120,
                    width: 240,
                    height: 240
                )
                showResult(payload, anchor: anchor, screen: screen)
                return
            }
        }

        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let payload = ContentParser.parse(text)
            let anchor = NSRect(
                x: screen.frame.midX - 120,
                y: screen.frame.midY - 120,
                width: 240,
                height: 240
            )
            showResult(payload, anchor: anchor, screen: screen)
            return
        }

        HUD.show("剪贴板里没有可识别的图片或文本", on: screen, isError: true)
    }

    private func cgImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.cgImage
    }

    @objc private func showWelcomeAction() {
        showWelcome()
    }

    private func showWelcome() {
        if welcomeWindow == nil {
            welcomeWindow = WelcomeWindow(
                onStart: { [weak self] in
                    self?.welcomeWindow?.orderOut(nil)
                    self?.startCapture()
                },
                onPermission: { [weak self] in
                    self?.showPermissionStatus()
                },
                onQuit: { [weak self] in
                    self?.quit()
                }
            )
        }
        welcomeWindow?.refresh()
        activateSelf()
        welcomeWindow?.makeKeyAndOrderFront(nil)

        // 系统权限弹窗会抢焦点；弹窗关闭后再把欢迎窗口拉回前台。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.welcomeWindow?.isVisible == true else { return }
            activateSelf()
            self.welcomeWindow?.makeKeyAndOrderFront(nil)
        }

        if !CaptureService.hasPermission && !didRequestPermission {
            didRequestPermission = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                _ = PermissionRepair.resetScreenCapture()
                _ = CaptureService.requestPermission()
                self?.welcomeWindow?.refresh()
            }
        } else if CaptureService.hasPermission && !didVerifyCapture {
            didVerifyCapture = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                let ok = await CaptureService.verifyCaptureAccess()
                debugLog("permission verify: \(ok)")
                if !ok {
                    _ = PermissionRepair.resetScreenCapture()
                    _ = CaptureService.requestPermission()
                    self.welcomeWindow?.refresh()
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        debugLog("reopen: show welcome")
        showWelcome()
        return true
    }

    @objc private func repairPermissionAction() {
        Alerts.show(
            title: "修复屏幕录制权限",
            message: "会清除本应用的屏幕录制授权并重新请求，用于旧授权残留或授权不生效。",
            buttons: ["继续", "取消"],
            style: .warning
        ) { [weak self] index in
            if index == 0 { self?.repairPermissionFlow() }
        }
    }

    private func repairPermissionFlow() {
        PermissionRepair.resetAndRequest()
        welcomeWindow?.refresh()
    }

    @objc private func showPermissionStatus() {
        if CaptureService.hasPermission {
            Alerts.show(title: "屏幕录制已授权", message: "可以开始框选。", buttons: ["好"])
            return
        }

        if didRequestPermission {
            // 启动时已经清理过旧授权并弹过系统请求，这里只负责把用户送到设置页。
            CaptureService.openPermissionSettings()
            welcomeWindow?.refresh()
            return
        }

        didRequestPermission = true
        let status = PermissionRepair.resetScreenCapture()
        _ = CaptureService.requestPermission()
        CaptureService.openPermissionSettings()
        welcomeWindow?.refresh()
        if status != 0 { Alerts.permission() }
    }

    @objc private func showAbout() {
        Alerts.show(
            title: "扫码助手 0.1.6 (P0)",
            message: "按 ⌃⌥Q 框选屏幕上的二维码。",
            buttons: ["好"]
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func cancelFlow() {
        overlayController?.close()
        overlayController = nil
        isCapturing = false
    }

    private func closeResult() {
        resultPanel?.orderOut(nil)
        resultPanel?.close()
        resultPanel = nil
    }

    private func runIntegrationTest() {
        debugLog("integration: start")
        guard CaptureService.hasPermission else {
            debugLog("integration: no screen permission")
            Alerts.permission()
            return
        }
        guard let screen = NSScreen.main else { return }

        let qrWindow = NSWindow(
            contentRect: NSRect(x: 300, y: 300, width: 320, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        qrWindow.isReleasedWhenClosed = false
        qrWindow.backgroundColor = .white
        qrWindow.isOpaque = true
        qrWindow.level = .floating
        let imageView = NSImageView(frame: NSRect(x: 20, y: 20, width: 280, height: 280))
        if let cg = QRCodeImage.make("https://pan.baidu.com/s/1QrDemo8xK?pwd=8xk2", scale: 10) {
            imageView.image = NSImage(cgImage: cg, size: NSSize(width: 280, height: 280))
        }
        imageView.imageScaling = .scaleProportionallyUpOrDown
        qrWindow.contentView = imageView
        qrWindow.orderFrontRegardless()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            do {
                let displays = try await CaptureService.captureAllDisplays(screens: NSScreen.screens)
                qrWindow.orderOut(nil)
                qrWindow.close()
                let localRect = NSRect(
                    x: qrWindow.frame.minX - screen.frame.minX,
                    y: qrWindow.frame.minY - screen.frame.minY,
                    width: qrWindow.frame.width,
                    height: qrWindow.frame.height
                )
                debugLog("integration: captured \(displays.count) display(s), select \(localRect)")
                self.presentOverlay(displays, autoSelect: (screen, localRect))
            } catch {
                qrWindow.orderOut(nil)
                qrWindow.close()
                debugLog("integration: capture failed \(error)")
                Alerts.dispatchFailed(error.localizedDescription)
            }
        }
    }

    private func runDemo() {
        debugLog("demo: start")
        guard let screen = NSScreen.main else { return }
        debugLog("demo: screen \(screen.frame)")
        guard let (image, rect) = DemoScene.make(size: screen.frame.size, twoCodes: multiDemo) else {
            debugLog("demo: scene failed")
            return
        }
        debugLog("demo: scene ready \(image.width)x\(image.height) selection=\(rect)")
        let display = CapturedDisplay(screen: screen, image: image)
        presentOverlay([display], autoSelect: (screen, rect))
        debugLog("demo: overlay presented")
    }
}
