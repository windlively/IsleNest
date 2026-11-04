import AppKit

final class IslandPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onMouseDownInside: (() -> Void)?
    var onResignKey: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        title = "栖岛"
        appearance = NSAppearance(named: .darkAqua)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if onKeyDown?(event) == true {
                return
            }
        case .leftMouseDown, .rightMouseDown:
            onMouseDownInside?()
        default:
            break
        }
        super.sendEvent(event)
    }
}
