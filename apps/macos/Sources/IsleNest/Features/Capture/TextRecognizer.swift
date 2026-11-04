import CoreGraphics
import CoreText
import Foundation
import Vision

enum TextRecognitionOutcome: Sendable {
    case text(String)
    case empty
    case failed
}

enum TextRecognizer {
    /// The first Vision OCR call compiles the recognition model (tens of seconds);
    /// running a tiny request up front keeps the first user-facing 取字 fast.
    static func warmUp() async {
        await Task.detached(priority: .utility) {
            guard let image = warmUpImage() else {
                return
            }
            _ = recognizeSynchronously(in: image)
        }.value
    }

    static func recognize(in image: CGImage) async -> TextRecognitionOutcome {
        await Task.detached(priority: .userInitiated) {
            recognizeSynchronously(in: image)
        }.value
    }

    private static func recognizeSynchronously(in image: CGImage) -> TextRecognitionOutcome {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failed
        }

        let lines = (request.results ?? [])
            .compactMap { observation -> (top: CGFloat, left: CGFloat, text: String)? in
                guard let text = observation.topCandidates(1).first?.string else {
                    return nil
                }
                return (observation.boundingBox.maxY, observation.boundingBox.minX, text)
            }
            .sorted { lhs, rhs in
                if abs(lhs.top - rhs.top) > 0.01 {
                    return lhs.top > rhs.top
                }
                return lhs.left < rhs.left
            }
            .map(\.text)

        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .empty : .text(text)
    }

    private static func warmUpImage() -> CGImage? {
        let width = 180
        let height = 48
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName("Helvetica" as CFString, 22, nil)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: "IsleNest 123",
                attributes: [
                    kCTFontAttributeName as NSAttributedString.Key: font,
                    kCTForegroundColorAttributeName as NSAttributedString.Key:
                        CGColor(red: 0, green: 0, blue: 0, alpha: 1)
                ]
            )
        )
        context.textPosition = CGPoint(x: 10, y: 14)
        CTLineDraw(line, context)
        return context.makeImage()
    }
}
