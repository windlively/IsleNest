import AppKit
import IsleNestCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private weak var controller: IslandController?
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem()

    init(controller: IslandController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        buildMenu()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        guard let button = statusItem.button, let window = button.window else {
            return false
        }
        let windowRect = button.convert(button.bounds, to: nil)
        return window.convertToScreen(windowRect).contains(point)
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }
        let icon = Self.makeIcon()
        icon.isTemplate = true
        button.image = icon
        button.toolTip = "栖岛"
        button.setAccessibilityLabel("栖岛")
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private static func makeIcon() -> NSImage {
        NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            let base = NSBezierPath(
                roundedRect: NSRect(x: 2, y: 4.5, width: 14, height: 5.5),
                xRadius: 2.75,
                yRadius: 2.75
            )
            base.fill()

            let dot = NSBezierPath(
                ovalIn: NSRect(x: 7.4, y: 11.4, width: 3.2, height: 3.2)
            )
            dot.fill()
            return true
        }
    }

    private func buildMenu() {
        menu.delegate = self

        toggleItem.target = self
        toggleItem.action = #selector(toggleIsland)
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let region = NSMenuItem(title: "区域截屏", action: #selector(captureRegion), keyEquivalent: "")
        region.target = self
        menu.addItem(region)

        let window = NSMenuItem(title: "窗口截屏", action: #selector(captureWindow), keyEquivalent: "")
        window.target = self
        menu.addItem(window)

        let display = NSMenuItem(title: "全屏截屏", action: #selector(captureDisplay), keyEquivalent: "")
        display.target = self
        menu.addItem(display)

        let scrolling = NSMenuItem(title: "滚动截屏", action: #selector(captureScrolling), keyEquivalent: "")
        scrolling.target = self
        menu.addItem(scrolling)

        let recording = NSMenuItem(title: "区域录屏", action: #selector(recordRegion), keyEquivalent: "")
        recording.target = self
        menu.addItem(recording)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let welcome = NSMenuItem(title: "欢迎引导", action: #selector(showWelcome), keyEquivalent: "")
        welcome.target = self
        menu.addItem(welcome)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "退出栖岛",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = nil
        menu.addItem(quit)
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isSecondaryClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isSecondaryClick {
            showMenu()
        } else {
            controller?.toggleIsland()
        }
    }

    private func showMenu() {
        guard let button = statusItem.button else {
            return
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 4),
            in: button
        )
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem.title = controller?.isIslandExpanded == true ? "收起栖岛" : "展开栖岛"
    }

    @objc private func toggleIsland() {
        controller?.toggleIsland()
    }

    @objc private func captureRegion() {
        controller?.startCapture(.region)
    }

    @objc private func captureWindow() {
        controller?.startCapture(.window)
    }

    @objc private func captureDisplay() {
        controller?.startCapture(.display)
    }

    @objc private func captureScrolling() {
        controller?.startScrollingCapture()
    }

    @objc private func recordRegion() {
        controller?.startRegionRecording()
    }

    @objc private func openSettings() {
        controller?.openSettings(tab: .general)
    }

    @objc private func showWelcome() {
        controller?.showOnboarding()
    }
}
