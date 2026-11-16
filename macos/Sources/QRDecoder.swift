import Foundation
import CoreGraphics
import CoreImage
import Vision

enum QRDecoder {
    static func decode(_ image: CGImage) -> [DecodedQR] {
        var results = decodeOnce(image)
        if results.isEmpty {
            for variant in variants(of: image) {
                results = decodeOnce(variant)
                if !results.isEmpty { break }
            }
        }
        return results.sorted { lhs, rhs in
            lhs.bounds.width * lhs.bounds.height > rhs.bounds.width * rhs.bounds.height
        }
    }

    private static func decodeOnce(_ image: CGImage) -> [DecodedQR] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard let value = observation.payloadStringValue, !value.isEmpty else { return nil }
            return DecodedQR(raw: value, bounds: observation.boundingBox)
        }
    }

    private static func variants(of image: CGImage) -> [CGImage] {
        var output: [CGImage] = []
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let source = CIImage(cgImage: image)

        let scaled = source.transformed(by: CGAffineTransform(scaleX: 2, y: 2))
        if let cg = context.createCGImage(scaled, from: scaled.extent) {
            output.append(cg)
        }

        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(source, forKey: kCIInputImageKey)
            filter.setValue(1.6, forKey: kCIInputContrastKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            if let out = filter.outputImage,
               let cg = context.createCGImage(out, from: out.extent) {
                output.append(cg)
            }
        }

        if let filter = CIFilter(name: "CIColorInvert") {
            filter.setValue(source, forKey: kCIInputImageKey)
            if let out = filter.outputImage,
               let cg = context.createCGImage(out, from: out.extent) {
                output.append(cg)
            }
        }

        return output
    }
}
