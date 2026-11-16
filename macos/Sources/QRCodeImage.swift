import Foundation
import CoreGraphics
import CoreImage

enum QRCodeImage {
    static func make(_ string: String, scale: CGFloat = 10) -> CGImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(string.data(using: .utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(transformed, from: transformed.extent)
    }
}
