import AppKit
import CoreGraphics
import CoreText
import Foundation

struct CaptureAnnotationStyle {
    var color: CGColor
    var lineWidth: CGFloat
    var fontSize: CGFloat
    var mosaicBlock: CGFloat

    static let defaultColor = CGColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)

    static let `default` = CaptureAnnotationStyle(
        color: defaultColor,
        lineWidth: 3,
        fontSize: 16,
        mosaicBlock: 10
    )

    var nsColor: NSColor {
        NSColor(cgColor: color) ?? .systemRed
    }

    static func fontSize(forLineWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<2.5: return 14
        case ..<4.5: return 16
        default: return 22
        }
    }

    static func mosaicBlock(forLineWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<2.5: return 6
        case ..<4.5: return 10
        default: return 16
        }
    }
}

struct CaptureAnnotation {
    enum Kind {
        case rectangle(CGRect)
        case ellipse(CGRect)
        case arrow(from: CGPoint, to: CGPoint)
        case pen(points: [CGPoint])
        case highlighter(points: [CGPoint])
        case number(Int, at: CGPoint)
        case text(String, at: CGPoint)
        case mosaic(CGRect)
    }

    var kind: Kind
    var style: CaptureAnnotationStyle
}

/// Annotation coordinates use points relative to the displayed image with the
/// origin at its bottom-left, matching the AppKit overlay view.
enum CaptureAnnotationRenderer {
    static func render(base: CGImage, annotations: [CaptureAnnotation], displaySize: CGSize) -> CGImage {
        guard !annotations.isEmpty,
              displaySize.width > 0,
              displaySize.height > 0 else {
            return base
        }

        let width = base.width
        let height = base.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return base
        }

        context.interpolationQuality = .high
        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))

        let scaleX = CGFloat(width) / displaySize.width
        let scaleY = CGFloat(height) / displaySize.height
        let scale = min(scaleX, scaleY)

        func mapped(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }

        func mapped(_ rect: CGRect) -> CGRect {
            CGRect(
                x: rect.minX * scaleX,
                y: rect.minY * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )
        }

        var pixelatedCache: [CGFloat: CGImage] = [:]

        for annotation in annotations {
            let style = annotation.style
            let strokeWidth = max(2, style.lineWidth * scale)

            switch annotation.kind {
            case .rectangle(let rect):
                guard rect.width >= 1, rect.height >= 1 else {
                    continue
                }
                context.setStrokeColor(style.color)
                context.setLineWidth(strokeWidth)
                context.stroke(mapped(rect))

            case .ellipse(let rect):
                guard rect.width >= 1, rect.height >= 1 else {
                    continue
                }
                context.setStrokeColor(style.color)
                context.setLineWidth(strokeWidth)
                context.strokeEllipse(in: mapped(rect))

            case .arrow(let from, let to):
                drawArrow(
                    in: context,
                    from: mapped(from),
                    to: mapped(to),
                    color: style.color,
                    lineWidth: strokeWidth
                )

            case .pen(let points):
                guard points.count >= 2 else {
                    continue
                }
                context.setStrokeColor(style.color)
                context.setLineWidth(strokeWidth)
                context.setLineJoin(.round)
                context.setLineCap(.round)
                context.beginPath()
                context.addLines(between: points.map(mapped))
                context.strokePath()

            case .highlighter(let points):
                guard points.count >= 2 else {
                    continue
                }
                context.saveGState()
                context.setAlpha(0.38)
                context.setStrokeColor(style.color)
                context.setLineWidth(max(6, style.lineWidth * 4) * scale)
                context.setLineJoin(.round)
                context.setLineCap(.round)
                context.beginPath()
                context.addLines(between: points.map(mapped))
                context.strokePath()
                context.restoreGState()

            case .number(let value, let at):
                drawNumber(
                    in: context,
                    value: value,
                    at: mapped(at),
                    fontSize: max(1, style.fontSize * scale),
                    color: style.color
                )

            case .text(let string, let at):
                drawText(
                    in: context,
                    string: string,
                    at: mapped(at),
                    fontSize: max(1, style.fontSize * scale),
                    color: style.color
                )

            case .mosaic(let rect):
                guard rect.width >= 1, rect.height >= 1 else {
                    continue
                }
                let block = style.mosaicBlock
                let pixelated = pixelatedCache[block] ?? {
                    let image = pixelatedImage(base: base, displaySize: displaySize, block: block)
                    pixelatedCache[block] = image
                    return image
                }()
                guard let pixelated else {
                    continue
                }
                context.saveGState()
                context.clip(to: mapped(rect))
                context.interpolationQuality = .none
                context.draw(pixelated, in: CGRect(x: 0, y: 0, width: width, height: height))
                context.restoreGState()
            }
        }

        return context.makeImage() ?? base
    }

    static func pixelatedImage(base: CGImage, displaySize: CGSize, block: CGFloat) -> CGImage? {
        guard displaySize.width > 0, displaySize.height > 0 else {
            return nil
        }
        let factor = max(
            2,
            Int((block * CGFloat(base.width) / displaySize.width).rounded())
        )
        let width = max(1, base.width / factor)
        let height = max(1, base.height / factor)
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
        context.interpolationQuality = .medium
        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func textBounds(string: String, at point: CGPoint, fontSize: CGFloat) -> CGRect {
        let line = textLine(string, fontSize: max(1, fontSize), color: CaptureAnnotationStyle.defaultColor)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        return CGRect(
            x: point.x,
            y: point.y - descent,
            width: width,
            height: ascent + descent
        )
    }

    static func textLine(_ string: String, fontSize: CGFloat, color: CGColor) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(.system, max(1, fontSize), nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, max(1, fontSize), nil)
        let attributed = NSAttributedString(
            string: string,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: color
            ]
        )
        return CTLineCreateWithAttributedString(attributed)
    }

    private static func drawText(
        in context: CGContext,
        string: String,
        at point: CGPoint,
        fontSize: CGFloat,
        color: CGColor
    ) {
        let line = textLine(string, fontSize: fontSize, color: color)
        context.textPosition = point
        CTLineDraw(line, context)
    }

    private static func drawNumber(
        in context: CGContext,
        value: Int,
        at center: CGPoint,
        fontSize: CGFloat,
        color: CGColor
    ) {
        let radius = max(9 * (fontSize / 14), fontSize * 0.85)
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.setFillColor(color)
        context.fillEllipse(in: circle)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.85))
        context.setLineWidth(max(1, fontSize * 0.08))
        context.strokeEllipse(in: circle)

        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize * 0.9, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize * 0.9, nil)
        let attributed = NSAttributedString(
            string: "\(value)",
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 1, alpha: 1)
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        context.textPosition = CGPoint(
            x: center.x - width / 2,
            y: center.y - (ascent - descent) / 2
        )
        CTLineDraw(line, context)
    }

    private static func drawArrow(
        in context: CGContext,
        from: CGPoint,
        to: CGPoint,
        color: CGColor,
        lineWidth: CGFloat
    ) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 1 else {
            return
        }

        let angle = atan2(dy, dx)
        let headLength = min(length * 0.6, max(10, lineWidth * 4.2))
        let headWidth = headLength * 0.62
        let shaftEnd = CGPoint(
            x: to.x - cos(angle) * headLength * 0.82,
            y: to.y - sin(angle) * headLength * 0.82
        )

        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.beginPath()
        context.move(to: from)
        context.addLine(to: shaftEnd)
        context.strokePath()

        let perpendicular = angle + .pi / 2
        let baseCenter = CGPoint(
            x: to.x - cos(angle) * headLength,
            y: to.y - sin(angle) * headLength
        )
        let left = CGPoint(
            x: baseCenter.x + cos(perpendicular) * headWidth / 2,
            y: baseCenter.y + sin(perpendicular) * headWidth / 2
        )
        let right = CGPoint(
            x: baseCenter.x - cos(perpendicular) * headWidth / 2,
            y: baseCenter.y - sin(perpendicular) * headWidth / 2
        )

        context.setFillColor(color)
        context.beginPath()
        context.move(to: to)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
    }
}
