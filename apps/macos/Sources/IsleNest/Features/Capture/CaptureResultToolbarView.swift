import AppKit

enum CaptureTool: String, CaseIterable {
    case rectangle
    case ellipse
    case arrow
    case pen
    case highlighter
    case number
    case text
    case mosaic

    var title: String {
        switch self {
        case .rectangle: return "矩形"
        case .ellipse: return "椭圆"
        case .arrow: return "箭头"
        case .pen: return "画笔"
        case .highlighter: return "高亮"
        case .number: return "序号"
        case .text: return "文字"
        case .mosaic: return "马赛克"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .arrow: return "arrow.up.right"
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .number: return "1.circle"
        case .text: return "t.square"
        case .mosaic: return "square.grid.3x3.fill"
        }
    }
}

@MainActor
final class CaptureResultToolbarView: NSView {
    var onSelectTool: ((CaptureTool) -> Void)?
    var onSelectColor: ((CGColor) -> Void)?
    var onSelectLineWidth: ((CGFloat) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onOCR: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onShare: (() -> Void)?
    var onPin: (() -> Void)?
    var onCancel: (() -> Void)?

    private let buttonSize: CGFloat = 30
    private let styleButtonSize: CGFloat = 24
    private let colorButtonSize: CGFloat = 22
    private let padding: CGFloat = 6
    private let spacing: CGFloat = 2
    private let rowGap: CGFloat = 6
    private let separatorWidth: CGFloat = 9

    private var toolButtons: [CaptureTool: CaptureToolbarButton] = [:]
    private var actionButtons: [CaptureToolbarButton] = []
    private var undoButton: CaptureToolbarButton?
    private var redoButton: CaptureToolbarButton?
    private var colorButtons: [CaptureColorSwatchButton] = []
    private var widthButtons: [CaptureToolbarButton] = []
    private var primaryItems: [NSView] = []
    private var styleItems: [NSView] = []
    private var isUndoAvailable = false
    private var isRedoAvailable = false
    private var isBusy = false

    static let palette: [(name: String, color: CGColor)] = [
        ("红色", CGColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)),
        ("橙色", CGColor(red: 1, green: 0.58, blue: 0, alpha: 1)),
        ("黄色", CGColor(red: 1, green: 0.84, blue: 0.04, alpha: 1)),
        ("绿色", CGColor(red: 0.18, green: 0.78, blue: 0.35, alpha: 1)),
        ("蓝色", CGColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)),
        ("紫色", CGColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 1)),
        ("白色", CGColor(red: 1, green: 1, blue: 1, alpha: 1)),
        ("黑色", CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ]

    static let lineWidths: [(name: String, value: CGFloat)] = [
        ("细", 2),
        ("中", 3),
        ("粗", 6)
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildItems()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        false
    }

    func preferredSize() -> NSSize {
        let width = max(rowWidth(primaryItems), rowWidth(styleItems)) + padding * 2
        let height = padding * 2 + buttonSize + rowGap + styleButtonSize
        return NSSize(width: width.rounded(.up), height: height)
    }

    func setSelectedTool(_ tool: CaptureTool?) {
        for (candidate, button) in toolButtons {
            button.isSelected = candidate == tool
        }
    }

    func setUndoEnabled(_ enabled: Bool) {
        isUndoAvailable = enabled
        undoButton?.isEnabled = enabled && !isBusy
    }

    func setRedoEnabled(_ enabled: Bool) {
        isRedoAvailable = enabled
        redoButton?.isEnabled = enabled && !isBusy
    }

    func setBusy(_ busy: Bool) {
        isBusy = busy
        for button in toolButtons.values {
            button.isEnabled = !busy
        }
        for button in actionButtons {
            button.isEnabled = !busy
        }
        for button in widthButtons {
            button.isEnabled = !busy
        }
        for button in colorButtons {
            button.isEnabled = !busy
        }
        undoButton?.isEnabled = isUndoAvailable && !busy
        redoButton?.isEnabled = isRedoAvailable && !busy
    }

    override func layout() {
        super.layout()

        let primaryY = bounds.height - padding - buttonSize
        var x = padding
        for item in primaryItems {
            let width = width(of: item)
            let height = item is CaptureToolbarSeparator ? 18 : buttonSize
            item.frame = NSRect(
                x: x,
                y: primaryY + (buttonSize - height) / 2,
                width: width,
                height: height
            )
            x += width + spacing
        }

        let styleY = padding
        var styleX = max(padding, (bounds.width - rowWidth(styleItems)) / 2)
        for item in styleItems {
            let width = width(of: item)
            let height = item is CaptureToolbarSeparator ? 14 : styleButtonSize
            item.frame = NSRect(
                x: styleX,
                y: styleY + (styleButtonSize - height) / 2,
                width: width,
                height: height
            )
            styleX += width + spacing
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        NSColor(calibratedWhite: 0.07, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
        NSColor.white.withAlphaComponent(0.12).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        border.lineWidth = 1
        border.stroke()
    }

    private func buildItems() {
        for tool in CaptureTool.allCases {
            let button = CaptureToolbarButton(symbol: tool.symbol, tooltip: tool.title)
            button.onClick = { [weak self] in
                self?.onSelectTool?(tool)
            }
            toolButtons[tool] = button
            primaryItems.append(button)
        }

        primaryItems.append(CaptureToolbarSeparator())

        let undo = CaptureToolbarButton(symbol: "arrow.uturn.backward", tooltip: "撤销 ⌘Z")
        undo.onClick = { [weak self] in
            self?.onUndo?()
        }
        undo.isEnabled = false
        undoButton = undo
        actionButtons.append(undo)
        primaryItems.append(undo)

        let redo = CaptureToolbarButton(symbol: "arrow.uturn.forward", tooltip: "重做 ⇧⌘Z")
        redo.onClick = { [weak self] in
            self?.onRedo?()
        }
        redo.isEnabled = false
        redoButton = redo
        actionButtons.append(redo)
        primaryItems.append(redo)

        primaryItems.append(CaptureToolbarSeparator())

        let ocr = CaptureToolbarButton(symbol: "text.viewfinder", tooltip: "取字 ⌘T")
        ocr.onClick = { [weak self] in
            self?.onOCR?()
        }
        actionButtons.append(ocr)
        primaryItems.append(ocr)

        let copy = CaptureToolbarButton(symbol: "doc.on.doc", tooltip: "复制 ⌘C")
        copy.onClick = { [weak self] in
            self?.onCopy?()
        }
        copy.isEmphasized = true
        actionButtons.append(copy)
        primaryItems.append(copy)

        let save = CaptureToolbarButton(symbol: "square.and.arrow.down", tooltip: "保存 ⌘S")
        save.onClick = { [weak self] in
            self?.onSave?()
        }
        actionButtons.append(save)
        primaryItems.append(save)

        let share = CaptureToolbarButton(symbol: "square.and.arrow.up", tooltip: "分享…")
        share.onClick = { [weak self] in
            self?.onShare?()
        }
        actionButtons.append(share)
        primaryItems.append(share)

        let pin = CaptureToolbarButton(symbol: "pin", tooltip: "贴图：钉在屏幕上")
        pin.onClick = { [weak self] in
            self?.onPin?()
        }
        actionButtons.append(pin)
        primaryItems.append(pin)

        let cancel = CaptureToolbarButton(symbol: "xmark", tooltip: "取消 Esc")
        cancel.onClick = { [weak self] in
            self?.onCancel?()
        }
        actionButtons.append(cancel)
        primaryItems.append(cancel)

        buildStyleItems()

        for item in primaryItems + styleItems {
            addSubview(item)
        }
    }

    private func buildStyleItems() {
        for (index, entry) in Self.palette.enumerated() {
            let button = CaptureColorSwatchButton(
                color: NSColor(cgColor: entry.color) ?? .systemRed,
                tooltip: "颜色：\(entry.name)"
            )
            button.isSelected = index == 0
            button.onClick = { [weak self] in
                self?.selectPaletteColor(at: index)
            }
            colorButtons.append(button)
            styleItems.append(button)
        }

        styleItems.append(CaptureToolbarSeparator())

        for (index, entry) in Self.lineWidths.enumerated() {
            let button = CaptureToolbarButton.lineWidth(
                entry.value,
                tooltip: "线宽：\(entry.name)"
            )
            button.isSelected = entry.value == CaptureAnnotationStyle.default.lineWidth
            button.onClick = { [weak self] in
                self?.selectLineWidth(at: index)
            }
            widthButtons.append(button)
            styleItems.append(button)
        }
    }

    private func selectPaletteColor(at index: Int) {
        guard index < Self.palette.count else {
            return
        }
        for (candidate, button) in colorButtons.enumerated() {
            button.isSelected = candidate == index
        }
        onSelectColor?(Self.palette[index].color)
    }

    private func selectLineWidth(at index: Int) {
        guard index < Self.lineWidths.count else {
            return
        }
        for (candidate, button) in widthButtons.enumerated() {
            button.isSelected = candidate == index
        }
        onSelectLineWidth?(Self.lineWidths[index].value)
    }

    private func rowWidth(_ items: [NSView]) -> CGFloat {
        let content = items.reduce(CGFloat.zero) { $0 + width(of: $1) }
        return content + CGFloat(max(0, items.count - 1)) * spacing
    }

    private func width(of item: NSView) -> CGFloat {
        if item is CaptureToolbarSeparator {
            return separatorWidth
        }
        if item is CaptureColorSwatchButton {
            return colorButtonSize
        }
        if let button = item as? CaptureToolbarButton, button.isLineWidthButton {
            return styleButtonSize
        }
        return buttonSize
    }
}

@MainActor
final class CaptureToolbarButton: NSButton {
    var onClick: (() -> Void)?
    var isSelected = false {
        didSet {
            updateAppearance()
        }
    }
    var isEmphasized = false {
        didSet {
            updateAppearance()
        }
    }
    private(set) var isLineWidthButton = false
    private var lineWidthValue: CGFloat = 0

    private var isHovered = false
    private var trackingAreaRef: NSTrackingArea?

    init(symbol: String, tooltip: String) {
        super.init(frame: .zero)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        image?.isTemplate = true
        self.image = image
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        refusesFirstResponder = true
        toolTip = tooltip
        setAccessibilityLabel(tooltip)
        target = self
        action = #selector(handleClick)
        wantsLayer = true
        layer?.cornerRadius = 6
        updateAppearance()
    }

    static func lineWidth(_ width: CGFloat, tooltip: String) -> CaptureToolbarButton {
        let button = CaptureToolbarButton(symbol: "circle.fill", tooltip: tooltip)
        button.isLineWidthButton = true
        button.lineWidthValue = width
        button.image = nil
        button.needsDisplay = true
        return button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 30, height: 30)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    override func draw(_ dirtyRect: NSRect) {
        if isLineWidthButton {
            let color = isSelected
                ? NSColor.white
                : NSColor.white.withAlphaComponent(isHovered ? 0.95 : 0.8)
            color.setFill()
            let height = lineWidthValue
            let rect = NSRect(
                x: (bounds.width - 14) / 2,
                y: (bounds.height - height) / 2,
                width: 14,
                height: height
            )
            NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2).fill()
        } else {
            super.draw(dirtyRect)
        }
    }

    @objc private func handleClick() {
        onClick?()
    }

    private func updateAppearance() {
        let active = isSelected || isEmphasized
        if active {
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            contentTintColor = .white
        } else if isHovered {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor
            contentTintColor = NSColor.white.withAlphaComponent(0.95)
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            contentTintColor = NSColor.white.withAlphaComponent(0.85)
        }
        alphaValue = isEnabled ? 1 : 0.38
        if isLineWidthButton {
            needsDisplay = true
        }
    }
}

@MainActor
final class CaptureColorSwatchButton: NSButton {
    var onClick: (() -> Void)?
    var isSelected = false {
        didSet {
            needsDisplay = true
        }
    }

    private let swatchColor: NSColor
    private var isHovered = false
    private var trackingAreaRef: NSTrackingArea?

    init(color: NSColor, tooltip: String) {
        self.swatchColor = color
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        refusesFirstResponder = true
        toolTip = tooltip
        setAccessibilityLabel(tooltip)
        target = self
        action = #selector(handleClick)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 22, height: 22)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    @objc private func handleClick() {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill = bounds.insetBy(dx: 4, dy: 4)
        let circle = NSBezierPath(ovalIn: fill)

        if isSelected {
            NSColor.white.setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.5, dy: 1.5))
            ring.lineWidth = 1.5
            ring.stroke()
        } else if isHovered {
            NSColor.white.withAlphaComponent(0.45).setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.5, dy: 1.5))
            ring.lineWidth = 1
            ring.stroke()
        }

        swatchColor.setFill()
        circle.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        circle.lineWidth = 0.5
        circle.stroke()
    }
}

@MainActor
final class CaptureToolbarSeparator: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.withAlphaComponent(0.16).setFill()
        NSRect(x: (bounds.width - 1) / 2, y: 0, width: 1, height: bounds.height).fill()
    }
}
