import AppKit
import CoreGraphics

@MainActor
final class RegionSelectionController {
    private var panel: RegionOverlayPanel?
    private var completion: ((CGRect?) -> Void)?

    var isSelecting: Bool {
        panel != nil
    }

    func select(
        on screen: NSScreen,
        hint: String = "拖动选择区域 · Esc 取消"
    ) async -> CGRect? {
        await withCheckedContinuation { continuation in
            present(on: screen, hint: hint) { rect in
                continuation.resume(returning: rect)
            }
        }
    }

    func cancel() {
        finish(nil)
    }

    private func present(
        on screen: NSScreen,
        hint: String,
        completion: @escaping (CGRect?) -> Void
    ) {
        guard panel == nil else {
            completion(nil)
            return
        }

        let panel = RegionOverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        let view = RegionSelectionView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            hintText: hint
        )
        view.autoresizingMask = [.width, .height]
        view.onFinish = { [weak self] rect in
            self?.finish(rect)
        }
        view.onCancel = { [weak self] in
            self?.finish(nil)
        }

        panel.contentView = view
        self.panel = panel
        self.completion = completion

        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
        NSCursor.crosshair.set()
    }

    private func finish(_ rect: CGRect?) {
        guard let panel, let completion else {
            return
        }
        self.panel = nil
        self.completion = nil
        panel.orderOut(nil)
        NSCursor.arrow.set()
        completion(rect)
    }
}

final class RegionOverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class RegionSelectionView: NSView {
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private let scaleX: CGFloat
    private let scaleY: CGFloat
    private let hintText: String
    private var dragStart: NSPoint?
    private var selectionRect: NSRect = .zero
    private var hasFinished = false

    init(frame frameRect: NSRect, screen: NSScreen, hintText: String = "拖动选择区域 · Esc 取消") {
        self.hintText = hintText
        let pointSize = screen.frame.size
        if let displayID = screen.displayID,
           let mode = CGDisplayCopyDisplayMode(displayID) {
            scaleX = CGFloat(mode.pixelWidth) / max(pointSize.width, 1)
            scaleY = CGFloat(mode.pixelHeight) / max(pointSize.height, 1)
        } else {
            scaleX = screen.backingScaleFactor
            scaleY = screen.backingScaleFactor
        }
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let dim = NSColor.black.withAlphaComponent(0.4)
        dim.setFill()

        if selectionRect.isEmpty {
            bounds.fill()
        } else {
            NSRect(x: 0, y: 0, width: bounds.width, height: selectionRect.minY).fill()
            NSRect(
                x: 0,
                y: selectionRect.maxY,
                width: bounds.width,
                height: max(0, bounds.height - selectionRect.maxY)
            ).fill()
            NSRect(
                x: 0,
                y: selectionRect.minY,
                width: selectionRect.minX,
                height: selectionRect.height
            ).fill()
            NSRect(
                x: selectionRect.maxX,
                y: selectionRect.minY,
                width: max(0, bounds.width - selectionRect.maxX),
                height: selectionRect.height
            ).fill()

            NSColor.systemBlue.withAlphaComponent(0.95).setStroke()
            let border = NSBezierPath(rect: selectionRect.insetBy(dx: 0.75, dy: 0.75))
            border.lineWidth = 1.5
            border.stroke()

            drawSizeLabel()
        }

        drawHint()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = clampedPoint(convert(event.locationInWindow, from: nil))
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else {
            return
        }
        let current = clampedPoint(convert(event.locationInWindow, from: nil))
        selectionRect = NSRect(
            x: min(dragStart.x, current.x),
            y: min(dragStart.y, current.y),
            width: abs(current.x - dragStart.x),
            height: abs(current.y - dragStart.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        guard selectionRect.width >= 6, selectionRect.height >= 6 else {
            selectionRect = .zero
            needsDisplay = true
            return
        }
        finish(selectionRect)
    }

    override func rightMouseDown(with event: NSEvent) {
        cancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancel()
            return
        }
        super.keyDown(with: event)
    }

    private func finish(_ rect: CGRect) {
        guard !hasFinished else {
            return
        }
        hasFinished = true
        onFinish?(rect)
    }

    private func cancel() {
        guard !hasFinished else {
            return
        }
        hasFinished = true
        onCancel?()
    }

    private func clampedPoint(_ point: NSPoint) -> NSPoint {
        NSPoint(
            x: min(max(point.x, 0), bounds.width),
            y: min(max(point.y, 0), bounds.height)
        )
    }

    private func drawHint() {
        let text = hintText as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.86)
        ]
        let textSize = text.size(withAttributes: attributes)
        let padding = NSSize(width: 12, height: 7)
        let pill = NSRect(
            x: (bounds.width - textSize.width) / 2 - padding.width,
            y: 24,
            width: textSize.width + padding.width * 2,
            height: textSize.height + padding.height * 2
        )
        NSColor(calibratedWhite: 0.05, alpha: 0.78).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        text.draw(
            at: NSPoint(x: pill.minX + padding.width, y: pill.minY + padding.height),
            withAttributes: attributes
        )
    }

    private func drawSizeLabel() {
        let width = Int((selectionRect.width * scaleX).rounded())
        let height = Int((selectionRect.height * scaleY).rounded())
        let text = "\(width) × \(height) px" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let padding = NSSize(width: 8, height: 4)
        var origin = NSPoint(
            x: selectionRect.minX,
            y: selectionRect.minY - textSize.height - padding.height * 2 - 6
        )
        if origin.y < 8 {
            origin.y = selectionRect.minY + 8
        }
        if origin.x + textSize.width + padding.width * 2 > bounds.width - 8 {
            origin.x = bounds.width - textSize.width - padding.width * 2 - 8
        }

        let pill = NSRect(
            x: origin.x,
            y: origin.y,
            width: textSize.width + padding.width * 2,
            height: textSize.height + padding.height * 2
        )
        NSColor(calibratedWhite: 0.05, alpha: 0.82).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 5, yRadius: 5).fill()
        text.draw(
            at: NSPoint(x: pill.minX + padding.width, y: pill.minY + padding.height),
            withAttributes: attributes
        )
    }
}
