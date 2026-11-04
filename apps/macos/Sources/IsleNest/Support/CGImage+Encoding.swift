import AppKit
import Foundation
import UniformTypeIdentifiers

extension CGImage {
    func pngData() -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return output as Data
    }

    func tiffData() -> Data? {
        let representation = NSBitmapImageRep(cgImage: self)
        return representation.representation(using: .tiff, properties: [:])
    }

    func scaledImage(maxWidth: CGFloat, maxHeight: CGFloat) -> NSImage {
        let widthScale = maxWidth / CGFloat(width)
        let heightScale = maxHeight / CGFloat(height)
        let scale = min(1, widthScale, heightScale)
        let image = NSImage(size: NSSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale))
        image.addRepresentation(NSBitmapImageRep(cgImage: self))
        return image
    }
}

extension NSImage {
    var pixelSizeDescription: String {
        guard let representation = representations.first else {
            return "未知尺寸"
        }
        return "\(representation.pixelsWide) × \(representation.pixelsHigh) px"
    }
}
