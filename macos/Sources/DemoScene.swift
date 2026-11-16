import Foundation
import AppKit
import CoreGraphics

enum DemoScene {
    static func make(size: NSSize, twoCodes: Bool = false) -> (CGImage, NSRect)? {
        guard let qrCG = QRCodeImage.make("https://pan.baidu.com/s/1QrDemo8xK?pwd=8xk2", scale: 8) else {
            return nil
        }
        let qrImage = NSImage(cgImage: qrCG, size: NSSize(width: 240, height: 240))
        let canvas = NSImage(size: size)

        debugLog("scene: lockFocus")
        canvas.lockFocus()
        let bounds = NSRect(origin: .zero, size: size)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.15, alpha: 1),
            NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.27, alpha: 1)
        ])?.draw(in: bounds, angle: -35)

        let windowRect = NSRect(
            x: max(80, size.width * 0.09),
            y: max(90, size.height * 0.18),
            width: min(820, size.width * 0.62),
            height: min(620, size.height * 0.66)
        )
        NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
        NSBezierPath(roundedRect: windowRect, xRadius: 14, yRadius: 14).fill()

        let titleBar = NSRect(x: windowRect.minX, y: windowRect.maxY - 42, width: windowRect.width, height: 42)
        NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
        NSBezierPath(roundedRect: titleBar, xRadius: 14, yRadius: 14).fill()
        NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
        NSRect(x: titleBar.minX, y: titleBar.minY, width: titleBar.width, height: 1).fill()

        for (index, color) in [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen].enumerated() {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: windowRect.minX + 18 + CGFloat(index) * 20,
                y: windowRect.maxY - 27,
                width: 11,
                height: 11
            )).fill()
        }

        let heading = "产品设计资料包" as NSString
        heading.draw(at: NSPoint(x: windowRect.minX + 36, y: windowRect.maxY - 92), withAttributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 0.10, alpha: 1)
        ])

        let caption = "来自：产品资料库 · 更新于 2 分钟前" as NSString
        caption.draw(at: NSPoint(x: windowRect.minX + 36, y: windowRect.maxY - 118), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor(calibratedWhite: 0.48, alpha: 1)
        ])

        let selection: NSRect
        if twoCodes {
            let cardSize: CGFloat = 230
            let gap: CGFloat = 24
            let first = NSRect(
                x: windowRect.midX - cardSize - gap / 2,
                y: windowRect.midY - cardSize / 2 - 10,
                width: cardSize,
                height: cardSize
            )
            let second = first.offsetBy(dx: cardSize + gap, dy: 0)
            for card in [first, second] {
                NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
                NSBezierPath(roundedRect: card, xRadius: 12, yRadius: 12).fill()
            }
            qrImage.draw(in: first.insetBy(dx: 15, dy: 15))
            if let secondCG = QRCodeImage.make("https://pan.quark.cn/s/1AbCdEf", scale: 8) {
                NSImage(cgImage: secondCG, size: NSSize(width: 200, height: 200))
                    .draw(in: second.insetBy(dx: 15, dy: 15))
            }
            let hint = "识别其中一个二维码" as NSString
            hint.draw(at: NSPoint(x: first.midX + (second.midX - first.midX) / 2 - 62,
                                  y: first.minY - 28), withAttributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor(calibratedWhite: 0.40, alpha: 1)
            ])
            selection = first.union(second).insetBy(dx: -8, dy: -8)
        } else {
            let cardSize: CGFloat = 280
            let card = NSRect(
                x: windowRect.midX - cardSize / 2,
                y: windowRect.midY - cardSize / 2 - 20,
                width: cardSize,
                height: cardSize
            )
            NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
            NSBezierPath(roundedRect: card, xRadius: 12, yRadius: 12).fill()

            qrImage.draw(in: NSRect(
                x: card.midX - 120,
                y: card.midY - 120,
                width: 240,
                height: 240
            ))

            let hint = "扫码保存到「产品资料」" as NSString
            hint.draw(at: NSPoint(x: card.midX - 62, y: card.minY - 28), withAttributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor(calibratedWhite: 0.40, alpha: 1)
            ])
            selection = card.insetBy(dx: -8, dy: -8)
        }

        canvas.unlockFocus()
        debugLog("scene: unlockFocus")

        guard let cg = canvas.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            debugLog("scene: no cgImage")
            return nil
        }
        debugLog("scene: cgImage \(cg.width)x\(cg.height)")
        // NSImage.cgImage 可能引用 NSImage 内部位图；重绘一份，避免 NSImage 释放后野指针。
        guard let copied = copyImage(cg) else { return nil }
        return (copied, selection)
    }

    private static func copyImage(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
