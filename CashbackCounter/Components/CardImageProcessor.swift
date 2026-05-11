import UIKit
import Vision
import CoreImage

struct CardImageProcessor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private static let cardAspectRatio: CGFloat = 1.586

    static func process(_ image: UIImage, targetWidth: CGFloat = 800) async -> Data? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let result = await Task.detached(priority: .userInitiated) { () -> Data? in
            let corrected = CardImageProcessor.detectAndCorrect(ciImage) ?? ciImage
            let enhanced = CardImageProcessor.enhanceColors(corrected)
            guard let output = CardImageProcessor.cropAndResize(enhanced, targetWidth: targetWidth) else { return nil }
            return output.jpegData(compressionQuality: 0.85)
        }.value

        return result
    }

    private static func detectAndCorrect(_ image: CIImage) -> CIImage? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.5
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 0.8

        guard let handler = try? VNImageRequestHandler(ciImage: image),
              (try? handler.perform([request])) != nil,
              let observation = request.results?.first as? VNRectangleObservation else {
            return nil
        }

        let extent = image.extent
        let topLeft = vnPointToCI(observation.topLeft, extent: extent)
        let topRight = vnPointToCI(observation.topRight, extent: extent)
        let bottomLeft = vnPointToCI(observation.bottomLeft, extent: extent)
        let bottomRight = vnPointToCI(observation.bottomRight, extent: extent)

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(topLeft, forKey: "inputTopLeft")
        filter.setValue(topRight, forKey: "inputTopRight")
        filter.setValue(bottomLeft, forKey: "inputBottomLeft")
        filter.setValue(bottomRight, forKey: "inputBottomRight")

        return filter.outputImage
    }

    private static func vnPointToCI(_ point: CGPoint, extent: CGRect) -> CIVector {
        CIVector(x: point.x * extent.width + extent.minX, y: point.y * extent.height + extent.minY)
    }

    private static func enhanceColors(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.12, forKey: kCIInputSaturationKey)
        filter.setValue(1.05, forKey: kCIInputContrastKey)
        return filter.outputImage ?? image
    }

    private static func cropAndResize(_ image: CIImage, targetWidth: CGFloat) -> UIImage? {
        let extent = image.extent
        let currentRatio = extent.width / extent.height
        let cropRect: CGRect
        if currentRatio > cardAspectRatio {
            let w = extent.height * cardAspectRatio
            cropRect = CGRect(x: extent.minX + (extent.width - w) / 2, y: extent.minY, width: w, height: extent.height)
        } else {
            let h = extent.width / cardAspectRatio
            cropRect = CGRect(x: extent.minX, y: extent.minY + (extent.height - h) / 2, width: extent.width, height: h)
        }

        let cropped = image.cropped(to: cropRect)
        let scale = targetWidth / cropRect.width
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgOutput = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgOutput)
    }
}
