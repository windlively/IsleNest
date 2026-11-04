import CoreGraphics
import Foundation

public final class ScrollStitcher {
    public enum AppendResult: Equatable {
        case started
        case appended(addedHeight: Int)
        case duplicate
        case noMatch
        case limitReached
    }

    public private(set) var image: CGImage?
    public private(set) var frameCount = 0
    public private(set) var appendedFrames = 0

    public var totalHeight: Int {
        image?.height ?? 0
    }

    private let sampleWidth: Int
    private let minimumOverlapRatio: Double
    private let maximumHeight: Int
    private var lastSignature: [UInt8] = []

    public init(
        minimumOverlapRatio: Double = 0.12,
        maximumHeight: Int = 20000
    ) {
        self.minimumOverlapRatio = minimumOverlapRatio
        self.maximumHeight = maximumHeight
        self.sampleWidth = 48
    }

    @discardableResult
    public func append(_ frame: CGImage) -> AppendResult {
        guard frame.width > 0, frame.height > 1 else {
            return .noMatch
        }

        let signature = Self.signature(of: frame, sampleWidth: sampleWidth)
        guard signature.count == frame.height * sampleWidth else {
            return .noMatch
        }
        frameCount += 1

        guard let current = image else {
            image = frame
            lastSignature = signature
            appendedFrames = 1
            return .started
        }

        guard frame.width == current.width,
              lastSignature.count == signature.count,
              let overlap = bestOverlap(with: signature) else {
            return .noMatch
        }

        let addedHeight = frame.height - overlap
        lastSignature = signature

        guard addedHeight > 0 else {
            return .duplicate
        }
        guard current.height + addedHeight <= maximumHeight else {
            return .limitReached
        }
        guard let bottom = frame.cropping(
            to: CGRect(x: 0, y: overlap, width: frame.width, height: addedHeight)
        ), let composed = Self.compose(top: current, bottom: bottom) else {
            return .noMatch
        }

        image = composed
        appendedFrames += 1
        return .appended(addedHeight: addedHeight)
    }

    private func bestOverlap(with newSignature: [UInt8]) -> Int? {
        let height = newSignature.count / sampleWidth
        let oldHeight = lastSignature.count / sampleWidth
        guard height == oldHeight else {
            return nil
        }

        let minimumOverlap = max(24, Int(Double(height) * minimumOverlapRatio))
        guard minimumOverlap < height else {
            return nil
        }

        var bestOverlap = 0
        var bestScore = Double.greatestFiniteMagnitude
        var bestAdjustedScore = Double.greatestFiniteMagnitude

        for overlap in stride(from: height, through: minimumOverlap, by: -1) {
            let oldStart = (oldHeight - overlap) * sampleWidth
            var totalDifference = 0
            var exceeded = false

            rowLoop: for row in 0..<overlap {
                let oldBase = oldStart + row * sampleWidth
                let newBase = row * sampleWidth
                for column in 0..<sampleWidth {
                    let difference = Int(lastSignature[oldBase + column])
                        - Int(newSignature[newBase + column])
                    totalDifference += abs(difference)
                }
                if Double(totalDifference) / Double((row + 1) * sampleWidth) > bestScore + 6 {
                    exceeded = true
                    break rowLoop
                }
            }

            guard !exceeded else {
                continue
            }

            let score = Double(totalDifference) / Double(overlap * sampleWidth)
            // Prefer the larger overlap when two alignments are visually equivalent.
            let adjusted = score - Double(overlap) * 0.000_001
            if adjusted < bestAdjustedScore {
                bestAdjustedScore = adjusted
                bestScore = score
                bestOverlap = overlap
            }
        }

        guard bestOverlap > 0, bestScore <= 10 else {
            return nil
        }
        return bestOverlap
    }

    private static func signature(of image: CGImage, sampleWidth: Int) -> [UInt8] {
        let height = image.height
        guard height > 0,
              let context = CGContext(
                  data: nil,
                  width: sampleWidth,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: sampleWidth,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            return []
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleWidth, height: height))

        guard let data = context.data else {
            return []
        }
        let buffer = data.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: buffer, count: sampleWidth * height))
    }

    private static func compose(top: CGImage, bottom: CGImage) -> CGImage? {
        let width = top.width
        let totalHeight = top.height + bottom.height
        guard width > 0, bottom.width == width, totalHeight > 0 else {
            return nil
        }

        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(top, in: CGRect(x: 0, y: bottom.height, width: width, height: top.height))
        context.draw(bottom, in: CGRect(x: 0, y: 0, width: width, height: bottom.height))
        return context.makeImage()
    }
}
