import AppKit
import os

@MainActor
final class CapturePinController {
    var onClose: (() -> Void)?

    private let image: CGImage
    private let screen: NSScreen
    private let anchor: CGRect
    private var panel: PinnedCapturePanel?

    init(image: CGImage, screen: NSScreen, anchor: CGRect) {
        self.image = image
        self.screen = screen
        self.anchor = anchor
    }

    func show() {
        guard panel == nil else {
            return
        }

        let scale = max(1, screen.backingScaleFactor)
        let natural = CGSize(
            width: CGFloat(image.width) / scale,
            height: CGFloat(image.height) / scale
        )
        let limit = CGSize(
            width: screen.visibleFrame.width * 0.9,
            height: screen.visibleFrame.height * 0.9
        )
        let fit = min(
            1,
            limit.width / max(natural.width, 1),
            limit.height / max(natural.height, 1)
        )
        let fitted = CGSize(
            width: natural.width * fit,
            height: natural.height * fit
        )
        // Enlarge tiny captures uniformly so the close button stays usable.
        let minSide: CGFloat = 48
        let enlarge = min(
            8,
            max(1, minSide / max(min(fitted.width, fitted.height), 1))
        )
        let scaled = CGSize(
            width: fitted.width * enlarge,
            height: fitted.height * enlarge
        )
        let extraFit = min(
            1,
            limit.width / max(scaled.width, 1),
            limit.height / max(scaled.height, 1)
        )
        let size = NSSize(
            width: (scaled.width * extraFit).rounded(),
            height: (scaled.height * extraFit).rounded()
        )

        var origin = NSPoint(
            x: anchor.midX - size.width / 2,
            y: anchor.midY - size.height / 2
        )
        let margin: CGFloat = 8
        origin.x = min(
            max(screen.visibleFrame.minX + margin, origin.x),
            screen.visibleFrame.maxX - size.width - margin
        )
        origin.y = min(
            max(screen.visibleFrame.minY + margin, origin.y),
            screen.visibleFrame.maxY - size.height - margin
        )

        let panel = PinnedCapturePanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .none

        let view = PinnedImageView(frame: NSRect(origin: .zero, size: size))
        view.image = image
        view.onRequestClose = { [weak self] in
            self?.close()
        }
        panel.contentView = view
        self.panel = panel

        // Stay non-key so the app underneath keeps focus, like a floating reference.
        panel.orderFrontRegardless()
        view.presentCloseHint()

        Logger.capture.info(
            "Pinned capture shown size=\(Int(size.width), privacy: .public)x\(Int(size.height), privacy: .public)"
        )
    }

    func close() {
        guard let panel else {
            return
        }
        self.panel = nil
        panel.orderOut(nil)

        let handler = onClose
        onClose = nil
        handler?()
    }
}

private final class PinnedCapturePanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class PinnedImageView: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    var onRequestClose: (() -> Void)?

    private let closeButton = PinnedCloseButton()
    private var trackingArea: NSTrackingArea?
    private var isMouseInside = false

    override var acceptsFirstResponder: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        closeButton.isBordered = false
        closeButton.image = NSImage(
            systemSymbolName: "xmark",
            accessibilityDescription: "关闭贴图"
        )
        closeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        closeButton.contentTintColor = .white
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        closeButton.layer?.cornerRadius = 11
        closeButton.layer?.cornerCurve = .continuous
        closeButton.alphaValue = 0
        closeButton.isHidden = true
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.toolTip = "关闭贴图（也可双击或右键）"
        addSubview(closeButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let side: CGFloat = 22
        closeButton.frame = NSRect(
            x: bounds.maxX - side - 8,
            y: bounds.maxY - side - 8,
            width: side,
            height: side
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let image else {
            return
        }

        NSColor.clear.setFill()
        bounds.fill()

        let content = bounds.insetBy(dx: 1, dy: 1)
        context.saveGState()
        context.interpolationQuality = .high
        context.addPath(
            CGPath(
                roundedRect: content,
                cornerWidth: 10,
                cornerHeight: 10,
                transform: nil
            )
        )
        context.clip()
        context.draw(image, in: content)
        context.restoreGState()

        let border = NSBezierPath(
            roundedRect: content.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 10,
            yRadius: 10
        )
        NSColor.white.withAlphaComponent(0.28).setStroke()
        border.lineWidth = 1
        border.stroke()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        setCloseVisible(true)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        setCloseVisible(false)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            onRequestClose?()
            return
        }
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRequestClose?()
    }

    func presentCloseHint() {
        isMouseInside = false
        setCloseVisible(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self, !self.isMouseInside else {
                return
            }
            self.setCloseVisible(false)
        }
    }

    private func setCloseVisible(_ visible: Bool) {
        if visible {
            closeButton.isHidden = false
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            closeButton.animator().alphaValue = visible ? 1 : 0
        } completionHandler: { [weak self] in
            guard let self, self.closeButton.alphaValue < 0.05 else {
                return
            }
            self.closeButton.isHidden = true
        }
    }

    @objc private func closePressed() {
        onRequestClose?()
    }
}

private final class PinnedCloseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
