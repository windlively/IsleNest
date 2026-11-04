import AppKit
import CoreGraphics

@MainActor
final class CaptureResultOverlayView: NSView, NSTextFieldDelegate {
    var onCancel: (() -> Void)?
    var onCopy: ((CGImage) -> Void)?
    var onSave: ((CGImage) -> Void)?
    var onShare: ((CGImage) -> Void)?
    var onOCR: ((CGImage) -> Void)?
    var onPin: ((CGImage) -> Void)?

    let baseImage: CGImage
    private(set) var imageRect: NSRect
    private(set) var isBusy = false

    private let contentSize: CGSize
    private var scrollOffset: CGFloat = 0

    private let toolbar = CaptureResultToolbarView(frame: .zero)
    private let toast = CaptureResultToastView()
    private var renderedImage: CGImage
    private var annotations: [CaptureAnnotation] = []
    private var redoStack: [CaptureAnnotation] = []
    private var currentStyle = CaptureAnnotationStyle.default
    private var selectedTool: CaptureTool?
    private var draft: CaptureAnnotation?
    private var draftStart: CGPoint?
    private var textField: NSTextField?
    private var textAnchor: CGPoint?
    private var textStyle: CaptureAnnotationStyle?
    private var textEditingOriginal: CaptureAnnotation?
    private var pixelatedPreview: CGImage?
    private var pixelatedPreviewBlock: CGFloat?
    private var toastHideWorkItem: DispatchWorkItem?

    init(frame frameRect: NSRect, image: CGImage, imageRect: NSRect, contentSize: CGSize? = nil) {
        self.baseImage = image
        self.imageRect = imageRect
        self.contentSize = contentSize ?? imageRect.size
        self.renderedImage = image
        super.init(frame: frameRect)
        wantsLayer = true
        buildSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        false
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    var displayedImage: CGImage {
        renderedImage
    }

    var isScrollable: Bool {
        maxScrollOffset > 0
    }

    private var maxScrollOffset: CGFloat {
        max(0, contentSize.height - imageRect.height)
    }

    private var contentOrigin: NSPoint {
        if contentSize.height < imageRect.height - 0.5 {
            return NSPoint(
                x: imageRect.minX,
                y: imageRect.midY - contentSize.height / 2
            )
        }
        return NSPoint(
            x: imageRect.minX,
            y: imageRect.maxY - contentSize.height + scrollOffset
        )
    }

    private var contentRect: NSRect {
        NSRect(origin: contentOrigin, size: contentSize)
    }

    func setBusy(_ busy: Bool) {
        guard isBusy != busy else {
            return
        }
        isBusy = busy
        toolbar.setBusy(busy)
        window?.invalidateCursorRects(for: self)
    }

    func showToast(_ message: String, autoHideAfter delay: TimeInterval? = 1.8) {
        toast.show(message)
        toast.isHidden = false
        toast.alphaValue = 1
        toastHideWorkItem?.cancel()
        toastHideWorkItem = nil
        needsLayout = true
        layoutSubtreeIfNeeded()

        guard let delay else {
            return
        }
        let item = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.toast.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                self?.toast.isHidden = true
            }
        }
        toastHideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        let size = toolbar.preferredSize()
        var origin = NSPoint(
            x: imageRect.midX - size.width / 2,
            y: imageRect.minY - 10 - size.height
        )
        if origin.y < 8 {
            let above = imageRect.maxY + 10
            if above + size.height <= bounds.height - 8 {
                origin.y = above
            } else {
                origin.y = imageRect.minY + 12
            }
        }
        origin.x = min(max(8, origin.x), max(8, bounds.width - size.width - 8))
        toolbar.frame = NSRect(origin: origin, size: size)

        let toastSize = toast.frame.size
        var toastY = toolbar.frame.maxY + 10
        if toastY + toastSize.height > bounds.height - 8 {
            toastY = toolbar.frame.minY - toastSize.height - 10
        }
        toast.frame.origin = NSPoint(
            x: min(
                max(8, toolbar.frame.midX - toastSize.width / 2),
                max(8, bounds.width - toastSize.width - 8)
            ),
            y: max(8, toastY)
        )
    }

    private func buildSubviews() {
        toolbar.onSelectTool = { [weak self] tool in
            self?.selectTool(tool)
        }
        toolbar.onSelectColor = { [weak self] color in
            self?.applyColor(color)
        }
        toolbar.onSelectLineWidth = { [weak self] width in
            self?.applyLineWidth(width)
        }
        toolbar.onUndo = { [weak self] in
            self?.undo()
        }
        toolbar.onRedo = { [weak self] in
            self?.redo()
        }
        toolbar.onCopy = { [weak self] in
            self?.requestCopy()
        }
        toolbar.onSave = { [weak self] in
            self?.requestSave()
        }
        toolbar.onShare = { [weak self] in
            self?.requestShare()
        }
        toolbar.onOCR = { [weak self] in
            self?.requestOCR()
        }
        toolbar.onPin = { [weak self] in
            guard let self, !self.isBusy else {
                return
            }
            self.commitTextEditing()
            self.onPin?(self.renderedImage)
        }
        toolbar.onCancel = { [weak self] in
            self?.onCancel?()
        }
        addSubview(toolbar)

        toast.isHidden = true
        addSubview(toast)
        needsLayout = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.clip(to: imageRect)
        context.interpolationQuality = .high
        context.draw(renderedImage, in: contentRect)
        context.restoreGState()

        if let draft, case .mosaic(let rect) = draft.kind, !rect.isEmpty {
            drawMosaicPreview(
                in: rect,
                color: draft.style.nsColor,
                block: draft.style.mosaicBlock,
                context: context
            )
        }

        drawDraft()

        NSColor.white.withAlphaComponent(0.9).setStroke()
        let border = NSBezierPath(rect: imageRect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }

    private func drawMosaicPreview(
        in rect: CGRect,
        color: NSColor,
        block: CGFloat,
        context: CGContext
    ) {
        guard let pixelated = pixelatedPreviewImage(block: block) else {
            return
        }
        context.saveGState()
        context.clip(to: imageRect)
        context.interpolationQuality = .none
        context.draw(pixelated, in: contentRect)
        context.restoreGState()

        color.withAlphaComponent(0.9).setStroke()
        let outline = NSBezierPath(rect: viewRect(fromImageRect: rect))
        outline.lineWidth = 1.5
        outline.stroke()
    }

    private func drawDraft() {
        guard let draft else {
            return
        }
        let style = draft.style
        let color = style.nsColor
        color.setStroke()
        color.setFill()

        switch draft.kind {
        case .rectangle(let rect):
            guard rect.width >= 1, rect.height >= 1 else {
                return
            }
            let path = NSBezierPath(rect: viewRect(fromImageRect: rect))
            path.lineWidth = style.lineWidth
            path.stroke()

        case .ellipse(let rect):
            guard rect.width >= 1, rect.height >= 1 else {
                return
            }
            let path = NSBezierPath(ovalIn: viewRect(fromImageRect: rect))
            path.lineWidth = style.lineWidth
            path.stroke()

        case .arrow(let from, let to):
            drawArrowDraft(
                from: viewPoint(fromImagePoint: from),
                to: viewPoint(fromImagePoint: to),
                color: color,
                lineWidth: style.lineWidth
            )

        case .pen(let points):
            guard points.count >= 2 else {
                return
            }
            let path = NSBezierPath()
            path.lineWidth = style.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: viewPoint(fromImagePoint: points[0]))
            for point in points.dropFirst() {
                path.line(to: viewPoint(fromImagePoint: point))
            }
            path.stroke()

        case .highlighter(let points):
            guard points.count >= 2 else {
                return
            }
            let path = NSBezierPath()
            path.lineWidth = max(6, style.lineWidth * 4)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: viewPoint(fromImagePoint: points[0]))
            for point in points.dropFirst() {
                path.line(to: viewPoint(fromImagePoint: point))
            }
            color.withAlphaComponent(0.38).setStroke()
            path.stroke()

        case .number, .mosaic, .text:
            break
        }
    }

    private func drawArrowDraft(
        from start: NSPoint,
        to end: NSPoint,
        color: NSColor,
        lineWidth: CGFloat
    ) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 1 else {
            return
        }

        let angle = atan2(dy, dx)
        let headLength = min(length * 0.6, max(10, lineWidth * 4.2))
        let headWidth = headLength * 0.62
        let shaftEnd = NSPoint(
            x: end.x - cos(angle) * headLength * 0.82,
            y: end.y - sin(angle) * headLength * 0.82
        )

        let shaft = NSBezierPath()
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        shaft.move(to: start)
        shaft.line(to: shaftEnd)
        shaft.stroke()

        let perpendicular = angle + .pi / 2
        let baseCenter = NSPoint(
            x: end.x - cos(angle) * headLength,
            y: end.y - sin(angle) * headLength
        )
        let left = NSPoint(
            x: baseCenter.x + cos(perpendicular) * headWidth / 2,
            y: baseCenter.y + sin(perpendicular) * headWidth / 2
        )
        let right = NSPoint(
            x: baseCenter.x - cos(perpendicular) * headWidth / 2,
            y: baseCenter.y - sin(perpendicular) * headWidth / 2
        )

        color.setFill()
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: left)
        head.line(to: right)
        head.close()
        head.fill()
    }

    // MARK: - Tools and annotations

    private func selectTool(_ tool: CaptureTool) {
        guard !isBusy else {
            return
        }
        commitTextEditing()
        selectedTool = tool
        toolbar.setSelectedTool(tool)
        window?.makeFirstResponder(self)
        window?.invalidateCursorRects(for: self)
    }

    private func applyColor(_ color: CGColor) {
        currentStyle.color = color
        if var edited = textStyle {
            edited.color = color
            textStyle = edited
            textField?.textColor = NSColor(cgColor: color)
        }
    }

    private func applyLineWidth(_ width: CGFloat) {
        currentStyle.lineWidth = width
        currentStyle.fontSize = CaptureAnnotationStyle.fontSize(forLineWidth: width)
        currentStyle.mosaicBlock = CaptureAnnotationStyle.mosaicBlock(forLineWidth: width)
        if var edited = textStyle {
            edited.lineWidth = width
            edited.fontSize = currentStyle.fontSize
            textStyle = edited
            textField?.font = .systemFont(ofSize: edited.fontSize)
        }
        pixelatedPreview = nil
        pixelatedPreviewBlock = nil
        needsDisplay = true
    }

    private func undo() {
        guard !isBusy, textField == nil else {
            return
        }
        guard let last = annotations.popLast() else {
            return
        }
        redoStack.append(last)
        refreshRenderedImage()
    }

    private func redo() {
        guard !isBusy, textField == nil else {
            return
        }
        guard let next = redoStack.popLast() else {
            return
        }
        annotations.append(next)
        refreshRenderedImage()
    }

    private func refreshRenderedImage() {
        renderedImage = CaptureAnnotationRenderer.render(
            base: baseImage,
            annotations: annotations,
            displaySize: contentSize
        )
        toolbar.setUndoEnabled(!annotations.isEmpty)
        toolbar.setRedoEnabled(!redoStack.isEmpty)
        needsDisplay = true
    }

    private func pixelatedPreviewImage(block: CGFloat) -> CGImage? {
        if let pixelatedPreview, pixelatedPreviewBlock == block {
            return pixelatedPreview
        }
        let image = CaptureAnnotationRenderer.pixelatedImage(
            base: baseImage,
            displaySize: contentSize,
            block: block
        )
        pixelatedPreview = image
        pixelatedPreviewBlock = block
        return image
    }

    // MARK: - Requests

    private func requestCopy() {
        guard !isBusy else {
            return
        }
        commitTextEditing()
        onCopy?(renderedImage)
    }

    private func requestSave() {
        guard !isBusy else {
            return
        }
        commitTextEditing()
        onSave?(renderedImage)
    }

    private func requestShare() {
        guard !isBusy else {
            return
        }
        commitTextEditing()
        onShare?(renderedImage)
    }

    private func requestOCR() {
        guard !isBusy else {
            return
        }
        commitTextEditing()
        onOCR?(baseImage)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            if textField != nil {
                cancelTextEditing()
            } else {
                onCancel?()
            }
        case 36, 76:
            requestCopy()
        default:
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if textField != nil {
            cancelTextEditing()
        } else {
            onCancel?()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard textField == nil, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c":
            requestCopy()
            return true
        case "s":
            requestSave()
            return true
        case "t":
            requestOCR()
            return true
        case "z":
            if event.modifierFlags.contains(.shift) {
                redo()
            } else {
                undo()
            }
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    // MARK: - Cursors

    override func resetCursorRects() {
        let cursor: NSCursor = selectedTool != nil && !isBusy ? .crosshair : .arrow
        addCursorRect(imageRect, cursor: cursor)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard imageRect.contains(location) else {
            cancelTextEditing()
            onCancel?()
            return
        }

        let point = clampedImagePoint(imagePoint(fromViewPoint: location))
        if event.clickCount >= 2,
           beginEditingExistingText(at: point) {
            return
        }

        commitTextEditing()
        guard !isBusy, let tool = selectedTool else {
            return
        }
        if tool == .text, beginEditingExistingText(at: point) {
            return
        }
        if tool == .number {
            appendAnnotation(CaptureAnnotation(kind: .number(nextNumber, at: point), style: currentStyle))
            refreshRenderedImage()
            return
        }

        draftStart = point

        switch tool {
        case .rectangle:
            draft = CaptureAnnotation(kind: .rectangle(CGRect(origin: point, size: .zero)), style: currentStyle)
        case .ellipse:
            draft = CaptureAnnotation(kind: .ellipse(CGRect(origin: point, size: .zero)), style: currentStyle)
        case .mosaic:
            draft = CaptureAnnotation(kind: .mosaic(CGRect(origin: point, size: .zero)), style: currentStyle)
        case .arrow:
            draft = CaptureAnnotation(kind: .arrow(from: point, to: point), style: currentStyle)
        case .pen:
            draft = CaptureAnnotation(kind: .pen(points: [point]), style: currentStyle)
        case .highlighter:
            draft = CaptureAnnotation(kind: .highlighter(points: [point]), style: currentStyle)
        case .number:
            draft = nil
        case .text:
            draft = nil
            beginTextEditing(at: point, viewPoint: location)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let currentDraft = draft, let start = draftStart else {
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        let point = clampedImagePoint(imagePoint(fromViewPoint: location))
        switch currentDraft.kind {
        case .rectangle:
            draft = CaptureAnnotation(kind: .rectangle(rectBetween(start, point)), style: currentDraft.style)
        case .ellipse:
            draft = CaptureAnnotation(kind: .ellipse(rectBetween(start, point)), style: currentDraft.style)
        case .mosaic:
            draft = CaptureAnnotation(kind: .mosaic(rectBetween(start, point)), style: currentDraft.style)
        case .arrow:
            draft = CaptureAnnotation(kind: .arrow(from: start, to: point), style: currentDraft.style)
        case .pen(var points):
            if let last = points.last,
               abs(point.x - last.x) + abs(point.y - last.y) < 1.5 {
                return
            }
            points.append(point)
            draft = CaptureAnnotation(kind: .pen(points: points), style: currentDraft.style)
        case .highlighter(var points):
            if let last = points.last,
               abs(point.x - last.x) + abs(point.y - last.y) < 1.5 {
                return
            }
            points.append(point)
            draft = CaptureAnnotation(kind: .highlighter(points: points), style: currentDraft.style)
        case .number, .text:
            return
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let draft else {
            return
        }
        self.draft = nil
        draftStart = nil

        switch draft.kind {
        case .rectangle(let rect):
            if rect.width >= 4, rect.height >= 4 {
                appendAnnotation(draft)
            }
        case .ellipse(let rect):
            if rect.width >= 4, rect.height >= 4 {
                appendAnnotation(draft)
            }
        case .mosaic(let rect):
            if rect.width >= 4, rect.height >= 4 {
                appendAnnotation(draft)
            }
        case .arrow(let from, let to):
            if abs(to.x - from.x) + abs(to.y - from.y) >= 10 {
                appendAnnotation(draft)
            }
        case .pen(let points):
            if points.count >= 2 {
                appendAnnotation(draft)
            }
        case .highlighter(let points):
            if points.count >= 2 {
                appendAnnotation(draft)
            }
        case .number, .text:
            break
        }

        refreshRenderedImage()
    }

    private func appendAnnotation(_ annotation: CaptureAnnotation) {
        annotations.append(annotation)
        redoStack.removeAll()
    }

    private var nextNumber: Int {
        let highest = annotations.compactMap { annotation -> Int? in
            if case .number(let value, _) = annotation.kind {
                return value
            }
            return nil
        }.max() ?? 0
        return highest + 1
    }

    override func rightMouseDown(with event: NSEvent) {
        if textField != nil {
            cancelTextEditing()
        } else {
            onCancel?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard maxScrollOffset > 0, textField == nil else {
            super.scrollWheel(with: event)
            return
        }
        let delta = event.hasPreciseScrollingDeltas
            ? event.scrollingDeltaY
            : event.scrollingDeltaY * 12
        let next = min(max(0, scrollOffset - delta), maxScrollOffset)
        guard next != scrollOffset else {
            return
        }
        scrollOffset = next
        needsDisplay = true
    }

    private func rectBetween(_ start: CGPoint, _ end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    // MARK: - Text editing

    @discardableResult
    private func beginEditingExistingText(at point: CGPoint) -> Bool {
        guard textField == nil, !isBusy else {
            return false
        }
        for index in annotations.indices.reversed() {
            guard case .text(let string, let at) = annotations[index].kind else {
                continue
            }
            let bounds = CaptureAnnotationRenderer.textBounds(
                string: string,
                at: at,
                fontSize: annotations[index].style.fontSize
            ).insetBy(dx: -4, dy: -3)
            guard bounds.contains(point) else {
                continue
            }

            let annotation = annotations.remove(at: index)
            textEditingOriginal = annotation
            textStyle = annotation.style
            selectedTool = .text
            toolbar.setSelectedTool(.text)
            refreshRenderedImage()

            let location = viewPoint(fromImagePoint: at)
            presentTextEditor(
                anchor: at,
                location: location,
                initialText: string,
                style: annotation.style
            )
            return true
        }
        return false
    }

    private func beginTextEditing(at point: CGPoint, viewPoint location: NSPoint) {
        textEditingOriginal = nil
        textStyle = nil
        presentTextEditor(
            anchor: point,
            location: location,
            initialText: "",
            style: currentStyle
        )
    }

    private func presentTextEditor(
        anchor: CGPoint,
        location: NSPoint,
        initialText: String,
        style: CaptureAnnotationStyle
    ) {
        let fieldHeight: CGFloat = max(24, style.fontSize + 10)
        let baselineOffset = style.fontSize * 0.3
        let minWidth: CGFloat = 140
        let textWidth = (initialText as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: style.fontSize)]
        ).width
        let availableWidth = max(minWidth, imageRect.maxX - location.x - 8)
        let width = min(260, max(minWidth, ceil(textWidth) + 16), availableWidth)
        var origin = NSPoint(
            x: location.x - 2,
            y: location.y - baselineOffset
        )
        origin.x = min(max(4, origin.x), max(4, bounds.width - width - 4))
        origin.y = min(max(4, origin.y), max(4, bounds.height - fieldHeight - 4))

        let field = NSTextField(frame: NSRect(origin: origin, size: NSSize(width: width, height: fieldHeight)))
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = true
        field.isSelectable = true
        field.focusRingType = .none
        field.font = .systemFont(ofSize: style.fontSize)
        field.textColor = style.nsColor
        field.stringValue = initialText
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = self
        field.wantsLayer = true
        field.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.32).cgColor
        field.layer?.cornerRadius = 3

        textField = field
        textAnchor = anchor
        addSubview(field, positioned: .above, relativeTo: nil)
        window?.makeFirstResponder(field)
        field.selectText(nil)
    }

    private func commitTextEditing() {
        guard let field = textField else {
            return
        }
        textField = nil
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let anchor = textAnchor
        let style = textStyle ?? currentStyle
        let wasEditingExisting = textEditingOriginal != nil
        textAnchor = nil
        textStyle = nil
        textEditingOriginal = nil
        window?.makeFirstResponder(self)
        field.removeFromSuperview()

        if !value.isEmpty, let anchor {
            annotations.append(CaptureAnnotation(kind: .text(value, at: anchor), style: style))
            redoStack.removeAll()
        }
        if wasEditingExisting || !value.isEmpty {
            refreshRenderedImage()
        }
    }

    private func cancelTextEditing() {
        guard let field = textField else {
            return
        }
        textField = nil
        let original = textEditingOriginal
        textAnchor = nil
        textStyle = nil
        textEditingOriginal = nil
        window?.makeFirstResponder(self)
        field.removeFromSuperview()

        if let original {
            annotations.append(original)
            refreshRenderedImage()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = textField, field === obj.object as? NSTextField else {
            return
        }
        let fontSize = textStyle?.fontSize ?? CaptureAnnotationStyle.default.fontSize
        let attributes: [NSAttributedString.Key: Any] = [
            .font: field.font ?? NSFont.systemFont(ofSize: fontSize)
        ]
        let textWidth = (field.stringValue as NSString).size(withAttributes: attributes).width
        let maxWidth = max(140, bounds.width - field.frame.minX - 8)
        let width = min(maxWidth, max(140, ceil(textWidth) + 16))
        field.setFrameSize(NSSize(width: width, height: field.frame.height))
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = textField, field === obj.object as? NSTextField else {
            return
        }
        commitTextEditing()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitTextEditing()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextEditing()
            return true
        }
        return false
    }

    // MARK: - Coordinates

    private func imagePoint(fromViewPoint point: NSPoint) -> CGPoint {
        CGPoint(x: point.x - contentOrigin.x, y: point.y - contentOrigin.y)
    }

    private func viewPoint(fromImagePoint point: CGPoint) -> NSPoint {
        NSPoint(x: contentOrigin.x + point.x, y: contentOrigin.y + point.y)
    }

    private func viewRect(fromImageRect rect: CGRect) -> NSRect {
        NSRect(
            x: contentOrigin.x + rect.minX,
            y: contentOrigin.y + rect.minY,
            width: rect.width,
            height: rect.height
        )
    }

    private func clampedImagePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), contentSize.width),
            y: min(max(point.y, 0), contentSize.height)
        )
    }
}

@MainActor
final class CaptureResultToastView: NSView {
    private let font = NSFont.systemFont(ofSize: 12, weight: .medium)
    private var text = ""

    override var isFlipped: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func show(_ message: String) {
        text = message
        let size = (message as NSString).size(withAttributes: [.font: font])
        frame.size = NSSize(width: ceil(size.width) + 26, height: 28)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        NSColor(calibratedWhite: 0.06, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
        NSColor.white.withAlphaComponent(0.14).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        border.lineWidth = 1
        border.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }
}
