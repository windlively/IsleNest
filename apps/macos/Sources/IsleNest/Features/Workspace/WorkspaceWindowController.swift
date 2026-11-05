import AppKit
import Combine
import IsleNestCore
import SwiftUI

@MainActor
final class WorkspaceWindowController: NSObject, NSWindowDelegate {
    private let config: ConfigStore
    private let services: WorkspaceServices
    private let actions: WorkspaceActions
    private let navigation = WorkspaceNavigation()
    private let onClose: () -> Void
    private var window: NSWindow?
    private var closeMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(
        config: ConfigStore,
        pomodoro: PomodoroTimer,
        recentFiles: RecentFilesStore,
        actions: WorkspaceActions,
        onClose: @escaping () -> Void
    ) {
        self.config = config
        self.services = WorkspaceServices(pomodoro: pomodoro, recentFiles: recentFiles)
        self.actions = actions
        self.onClose = onClose
        super.init()

        config.$settings
            .map(\.appearance)
            .removeDuplicates()
            .sink { [weak self] appearance in
                self?.window?.appearance = appearance.nsAppearance
            }
            .store(in: &cancellables)
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func show(section: WorkspaceSection = .overview, settingsTab: SettingsTab? = nil) {
        navigation.section = section
        if let settingsTab {
            navigation.settingsTab = settingsTab
        }

        if window == nil {
            let root = WorkspaceRootView(
                config: config,
                navigation: navigation,
                services: services,
                actions: actions
            )
            let hosting = NSHostingController(rootView: root)
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.title = "栖岛工作台"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = config.settings.appearance.nsAppearance
            window.setContentSize(NSSize(width: 1120, height: 720))
            window.minSize = NSSize(width: 980, height: 640)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.standardWindowButton(.closeButton)?.isEnabled = true
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = true
            window.center()
            self.window = window
            installCloseMonitor(for: window)
        }

        guard let window else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func installCloseMonitor(for window: NSWindow) {
        closeMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak window] event in
            guard let window, event.window === window,
                  let button = window.standardWindowButton(.closeButton),
                  !button.isHidden else {
                return event
            }
            let frame = button.convert(button.bounds, to: nil)
            guard frame.contains(event.locationInWindow) else {
                return event
            }
            window.performClose(nil)
            return nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    deinit {
        if let closeMonitor {
            NSEvent.removeMonitor(closeMonitor)
        }
    }
}
