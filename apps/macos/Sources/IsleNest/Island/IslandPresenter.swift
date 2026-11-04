import AppKit
import SwiftUI

@MainActor
final class IslandPresenter {
    let panel: IslandPanel
    var onKeyDown: ((NSEvent) -> Bool)? {
        didSet {
            panel.onKeyDown = onKeyDown
        }
    }
    var onMouseInteraction: (() -> Void)? {
        didSet {
            panel.onMouseDownInside = onMouseInteraction
        }
    }
    var onResignKey: (() -> Void)? {
        didSet {
            panel.onResignKey = onResignKey
        }
    }
    var onFrameApplied: ((CGSize) -> Void)?

    init() {
        let initialRect = NSRect(
            x: 0,
            y: 0,
            width: IslandTheme.collapsedSize.width + IslandTheme.shadowInset * 2,
            height: IslandTheme.collapsedSize.height + IslandTheme.shadowInset * 2
        )
        panel = IslandPanel(contentRect: initialRect)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var isKeyWindow: Bool {
        panel.isKeyWindow
    }

    func installRootView<Content: View>(_ content: Content) {
        let hosting = IslandHostingView(rootView: content)
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    func applyAppearance(_ appearance: NSAppearance?) {
        panel.appearance = appearance
        panel.contentView?.needsDisplay = true
    }

    func show(layout: IslandLayout, makeKey: Bool) {
        applyFrame(layout)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        if makeKey {
            panel.makeKey()
        }
    }

    func applyFrame(_ layout: IslandLayout) {
        let target = layout.windowRect
        if panel.frame != target {
            // Let the next SwiftUI layout draw the resized window; an immediate display would show stale, leading-anchored content.
            panel.setFrame(target, display: false)
        }
        onFrameApplied?(target.size)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func resignKey() {
        if panel.isKeyWindow {
            panel.resignKey()
        }
    }

    var panelWindow: NSWindow {
        panel
    }
}

final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
