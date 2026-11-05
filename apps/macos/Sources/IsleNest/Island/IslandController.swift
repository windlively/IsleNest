import AppKit
import Combine
import CoreGraphics
import IsleNestCore
import KeyboardShortcuts
import ScreenCaptureKit
import UniformTypeIdentifiers
import os

@MainActor
final class IslandController: NSObject {
    let config: ConfigStore

    private let model = IslandModel()
    private var scenes: [IslandScene] = []
    private weak var activeScene: IslandScene?
    private let display: DisplayCoordinator
    private let captureService = CaptureService()
    private let regionSelector = RegionSelectionController()
    private let windowPicker = WindowPickerController()
    private let scrollingCapture = ScrollingCaptureController()
    private let regionRecording = RegionRecordingController()
    private let pomodoro = PomodoroTimer()
    private let recentFiles = RecentFilesStore()
    private var colorSampler: NSColorSampler?
    private var shelfSharePicker: NSSharingServicePicker?
    private var resultSharePicker: NSSharingServicePicker?

    private var statusBar: StatusBarController?
    private var cancellables: Set<AnyCancellable> = []
    private var hoverExpandWorkItem: DispatchWorkItem?
    private var hoverCollapseWorkItem: DispatchWorkItem?
    private var collapseTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var peekResetTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var captureTask: Task<Void, Never>?
    private var globalMouseMonitor: Any?
    private var hoverTimer: Timer?
    private var hoveredScenes: Set<ObjectIdentifier> = []
    private var menuBarAccessGuardUntil = Date.distantPast
    private var focusItems: [IslandFocusID] = []
    private var captureScene: IslandScene?
    private var captureResultOverlay: CaptureResultOverlayController?
    private var recordingResultHUD: CaptureHUDController?
    private var pinnedCaptures: [CapturePinController] = []

    private var suspensionCount = 0
    private var isCapturing = false
    private var isSystemHidden = false
    private var isWorkspaceOpen = false
    private var isOnboardingOpen = false
    private var isPresentingCaptureResult = false
    private var hoverArmed = true

    private var workspaceWindow: WorkspaceWindowController!

    private lazy var onboardingWindow = OnboardingWindowController { [weak self] in
        self?.onboardingDidFinish()
    }

    var isIslandExpanded: Bool {
        model.isExpanded && activeScene?.presenter.isVisible == true
    }

    init(config: ConfigStore) {
        self.config = config
        self.display = DisplayCoordinator(config: config)
        IslandTheme.apply(config.settings.theme)
        super.init()

        workspaceWindow = WorkspaceWindowController(
            config: config,
            pomodoro: pomodoro,
            recentFiles: recentFiles,
            actions: WorkspaceActions(
                capture: { [weak self] kind in self?.captureFromWorkspace(kind) },
                recordRegion: { [weak self] in
                    self?.workspaceWindow.close()
                    self?.startRegionRecording()
                },
                sampleColor: { [weak self] in self?.sampleColor() },
                revealFile: { url in NSWorkspace.shared.activateFileViewerSelecting([url]) }
            ),
            onClose: { [weak self] in self?.workspaceDidClose() }
        )
    }

    func start() {
        configurePomodoro()
        observeNotifications()
        observeConfiguration()
        registerShortcut()
        statusBar = StatusBarController(controller: self)
        rebuildScenes(preferredDisplayID: nil)
        installGlobalMouseMonitor()
        startHoverTracking()
        updateFocusItems()

        let notchCount = scenes.filter { $0.style == .notch }.count
        Logger.island.info(
            "Started style=\(self.config.settings.style.rawValue, privacy: .public) notchScreens=\(notchCount, privacy: .public) screens=\(NSScreen.screens.count, privacy: .public)"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.config.settings.onboardingCompleted else {
                return
            }
            self.showOnboarding()
        }
        scheduleTextRecognitionWarmUp()
    }

    private func scheduleTextRecognitionWarmUp() {
        let warmUpKey = "app.islenest.ocrWarmed"
        guard !UserDefaults.standard.bool(forKey: warmUpKey) else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            UserDefaults.standard.set(true, forKey: warmUpKey)
            Task(priority: .utility) {
                await TextRecognizer.warmUp()
            }
        }
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        cancellables.removeAll()
        cancelHoverTimers()
        cancelScheduledCollapses()
        cancelScheduledPeekResets()
        regionSelector.cancel()
        windowPicker.cancel()
        scrollingCapture.cancel()
        regionRecording.cancel()
        captureResultOverlay?.cancelForTermination()
        captureResultOverlay = nil
        isPresentingCaptureResult = false
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoveredScenes.removeAll()
        statusBar?.remove()
        for scene in scenes {
            scene.presenter.hide()
        }
        scenes.removeAll()
        activeScene = nil
    }

    private func installGlobalMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            let location = NSEvent.mouseLocation
            DispatchQueue.main.async {
                self?.handleGlobalMouseDown(at: location)
            }
        }
    }

    private func startHoverTracking() {
        guard hoverTimer == nil else {
            return
        }
        // The notch panel's window covers the expanded envelope, so hover is derived
        // from the visible island shape instead of the window or hosting-view bounds.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateHoverState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func updateHoverState() {
        let location = NSEvent.mouseLocation
        for scene in scenes {
            let key = ObjectIdentifier(scene)
            let isHovering = hoverRect(for: scene).contains(location)
            // Fused islands retain a large transparent window for their morph animation.
            // Let clicks through that invisible envelope reach the app underneath.
            let shouldIgnoreMouse = !isHovering && !model.isDropTargeted
            if scene.presenter.panel.ignoresMouseEvents != shouldIgnoreMouse {
                scene.presenter.panel.ignoresMouseEvents = shouldIgnoreMouse
            }
            let wasHovering = hoveredScenes.contains(key)
            guard isHovering != wasHovering else {
                continue
            }
            if isHovering {
                hoveredScenes.insert(key)
            } else {
                hoveredScenes.remove(key)
            }
            hoverChanged(isHovering, on: scene)
        }
        collapseIfMenuBarAccessed(at: location)
    }

    private func hoverRect(for scene: IslandScene) -> NSRect {
        if model.isExpanded, scene === activeScene {
            return scene.expandedLayout.islandRect
        }
        return scene.isPeeking ? scene.peekLayout.islandRect : scene.collapsedLayout.islandRect
    }

    private func collapseIfMenuBarAccessed(at location: NSPoint) {
        guard model.isExpanded,
              Date() >= menuBarAccessGuardUntil,
              !isCapturing,
              !isSystemHidden,
              !isOnboardingOpen,
              suspensionCount == 0,
              let scene = activeScene,
              scene.style != .floating,
              scene.screen.frame.contains(location),
              statusBar?.containsScreenPoint(location) != true else {
            return
        }

        let menuBarHeight = max(scene.screen.frame.maxY - scene.screen.visibleFrame.maxY, 24)
        let accessBand = NSRect(
            x: scene.screen.frame.minX,
            y: scene.screen.frame.maxY - menuBarHeight - 2,
            width: scene.screen.frame.width,
            height: menuBarHeight + 2
        )
        // The expanded panel's own top bar sits in this band; only collapse when the
        // pointer approaches the menu bar outside the island's visible width.
        guard accessBand.contains(location),
              !scene.expandedLayout.islandRect.contains(location) else {
            return
        }
        collapse(animated: true)
    }

    // MARK: - Scenes

    private func rebuildScenes(preferredDisplayID: CGDirectDisplayID?) {
        let wasExpanded = model.isExpanded
        let previousDisplayID = preferredDisplayID ?? activeScene?.displayID

        cancelHoverTimers()
        cancelScheduledCollapses()
        cancelScheduledPeekResets()
        hoveredScenes.removeAll()
        for scene in scenes {
            scene.presenter.hide()
        }
        scenes.removeAll()
        activeScene = nil

        let screens = display.screens
        guard !screens.isEmpty else {
            return
        }

        for screen in screens {
            let scene = IslandScene(
                screen: screen,
                collapsed: display.layout(expanded: false, showsTimer: pomodoro.isActive, on: screen),
                peek: display.layout(expanded: false, peeking: true, showsTimer: pomodoro.isActive, on: screen),
                expanded: display.layout(expanded: true, on: screen)
            )
            installView(for: scene)
            scenes.append(scene)
        }

        let target = scenes.first { $0.displayID == previousDisplayID }
            ?? sceneUnderMouse()
            ?? scenes[0]
        activeScene = target
        target.setActive(true)

        showAllCollapsed()
        updateFocusItems()

        if wasExpanded,
           !isSystemHidden,
           !isCapturing,
           !isOnboardingOpen,
           scenes.contains(where: { $0 === target }) {
            expand(on: target, makeKey: false)
        }
    }

    // A physical notch is always black; keeping the fused panel dark in light mode
    // is the only way the bar and expanded surface stay visually connected to it.
    private func applyAppearance(for scene: IslandScene) {
        let style = display.resolvedStyle(for: scene.screen)
        let appearance = style == .notch
            ? NSAppearance(named: .darkAqua)
            : config.settings.appearance.nsAppearance
        scene.presenter.applyAppearance(appearance)
    }

    private func installView(for scene: IslandScene) {
        scene.presenter.installRootView(
            IslandRootView(
                model: model,
                scene: scene,
                config: config,
                timer: pomodoro,
                recentFiles: recentFiles,
                actions: makeActions(for: scene)
            )
        )
        applyAppearance(for: scene)
        scene.presenter.onKeyDown = { [weak self, weak scene] event in
            guard let self, let scene else {
                return false
            }
            return self.handleKeyDown(on: scene, event: event)
        }
        scene.presenter.onMouseInteraction = { [weak self] in
            self?.model.keyboardFocusVisible = false
        }
        scene.presenter.onResignKey = { [weak self, weak scene] in
            guard let self, let scene else {
                return
            }
            self.sceneDidResignKey(scene)
        }
        scene.presenter.onFrameApplied = { [weak scene] size in
            scene?.setWindowSize(size)
        }
    }

    private func sceneUnderMouse() -> IslandScene? {
        guard let screen = display.screen(containing: NSEvent.mouseLocation) else {
            return nil
        }
        return scenes.first { $0.displayID == screen.displayID }
    }

    private func scene(at location: NSPoint) -> IslandScene? {
        scenes.first { scene in
            let isExpandedHere = model.isExpanded && activeScene === scene
            let rect: NSRect
            if isExpandedHere {
                rect = scene.expandedLayout.islandRect
            } else if scene.isPeeking {
                rect = scene.peekLayout.islandRect
            } else {
                rect = scene.collapsedLayout.islandRect
            }
            return rect.contains(location)
        }
    }

    private func activate(_ scene: IslandScene) {
        for candidate in scenes {
            candidate.setActive(candidate === scene)
        }
        activeScene = scene
    }

    // MARK: - Actions used by the island UI

    private func makeActions(for scene: IslandScene) -> IslandActions {
        IslandActions(
            toggle: { [weak self, weak scene] in
                guard let scene else {
                    return
                }
                self?.toggleIsland(on: scene)
            },
            collapse: { [weak self] in self?.collapse(animated: true) },
            capture: { [weak self, weak scene] kind in
                guard let scene else {
                    return
                }
                self?.startCapture(kind, from: scene)
            },
            recordRegion: { [weak self, weak scene] in
                guard let scene else {
                    return
                }
                self?.startRegionRecording(from: scene)
            },
            addFolder: { [weak self] in self?.addFolders() },
            manageFolders: { [weak self] in self?.openSettings(tab: .folders) },
            addLaunch: { [weak self] in self?.addApplications() },
            editLaunch: { [weak self] in self?.openSettings(tab: .launch) },
            openFolder: { [weak self] id in self?.openFolder(id) },
            openLaunch: { [weak self] id in self?.openLaunch(id) },
            openWorkspace: { [weak self] in self?.openWorkspace() },
            copyResult: { [weak self] in self?.copyResult() },
            saveResult: { [weak self] in self?.saveResult() },
            shareResult: { [weak self] in self?.shareResult() },
            recognizeResultText: { [weak self] in self?.recognizeResultText() },
            revealResult: { [weak self] in self?.revealResult() },
            closeResult: { [weak self] in self?.closeResult(returnToTools: true) },
            dismissNotice: { [weak self] in self?.model.dismissNotice() },
            openLocation: { [weak self] in self?.openLocation($0) },
            nextFolderPage: { [weak self] in self?.nextPage(folders: true) },
            nextLaunchPage: { [weak self] in self?.nextPage(folders: false) },
            pinURLs: { [weak self] in self?.pinURLs($0) ?? false },
            dragTargetChanged: { [weak self, weak scene] targeted in
                guard let self, let scene else { return }
                self.model.isDropTargeted = targeted
                if targeted, !self.isCapturing, !self.isOnboardingOpen {
                    self.cancelHoverTimers()
                    if !self.model.isExpanded { self.expand(on: scene, makeKey: false) }
                }
            },
            addWebsite: { [weak self] in self?.addWebsite() },
            retakeResult: { [weak self] in
                guard let self, !self.model.isResultBusy, let kind = self.model.result?.kind else { return }
                self.startCapture(kind)
            },
            toggleShelf: { [weak self] in self?.toggleShelf() },
            togglePomodoro: { [weak self] in self?.togglePomodoro() },
            pomodoroToggle: { [weak self] in self?.pomodoro.toggle() },
            pomodoroReset: { [weak self] in self?.pomodoro.reset() },
            pomodoroSkip: { [weak self] in self?.pomodoro.skip() },
            openRecentFile: { [weak self] url in self?.openRecentFile(url) },
            sampleColor: { [weak self] in self?.sampleColor() },
            addShelfFiles: { [weak self] in self?.addShelfFiles() },
            shelfDrop: { [weak self] in self?.shelfDrop($0) ?? false },
            openShelfItem: { [weak self] id in self?.openShelfItem(id) },
            revealShelfItem: { [weak self] id in self?.revealShelfItem(id) },
            copyShelfPath: { [weak self] id in self?.copyShelfPath(id) },
            shareShelfItem: { [weak self] id in self?.shareShelfItem(id) },
            removeShelfItem: { [weak self] id in self?.removeShelfItem(id) },
            clearShelf: { [weak self] in self?.clearShelf() }
        )
    }

    func toggleIsland() {
        if isIslandExpanded, let activeScene {
            toggleIsland(on: activeScene)
        } else {
            toggleIsland(on: sceneUnderMouse() ?? activeScene)
        }
    }

    private func toggleIsland(on scene: IslandScene?) {
        guard !isCapturing, !isSystemHidden, !isOnboardingOpen, !isPresentingCaptureResult else {
            return
        }
        guard let scene else {
            return
        }
        if isIslandExpanded, activeScene === scene {
            collapse(animated: true)
        } else {
            expand(on: scene, makeKey: true)
        }
    }

    private func expand(on scene: IslandScene, makeKey: Bool) {
        guard !isSystemHidden, !isOnboardingOpen else {
            return
        }
        guard scenes.contains(where: { $0 === scene }) else {
            return
        }

        cancelHoverTimers()
        cancelScheduledCollapse(for: scene)
        cancelScheduledPeekReset(for: scene)

        let previous = activeScene
        if let previous, previous !== scene {
            previous.setActive(false)
            resetPeeking(for: previous)
        }
        activate(scene)
        if let previous, previous !== scene, previous.presenter.isVisible {
            previous.presenter.resignKey()
            scheduleCollapsedFrame(for: previous, animated: true)
        }

        scene.presenter.show(layout: scene.expandedLayout, makeKey: makeKey)
        model.isExpanded = true
        model.keyboardFocusVisible = false
        hoverArmed = true
        menuBarAccessGuardUntil = Date().addingTimeInterval(0.45)
        updateFocusItems()
        if model.selectedFocus == nil {
            model.selectedFocus = focusItems.first
        }
    }

    private func collapse(animated: Bool) {
        guard model.isExpanded || activeScene?.presenter.isVisible == true else {
            return
        }
        cancelHoverTimers()
        model.isExpanded = false
        model.isDropTargeted = false
        model.keyboardFocusVisible = false
        model.showsShelf = false
        model.showsPomodoro = false
        hoverArmed = true

        guard let scene = activeScene else {
            return
        }
        if !scene.collapsedLayout.islandRect.contains(NSEvent.mouseLocation) {
            resetPeeking(for: scene)
        }
        scheduleCollapsedFrame(for: scene, animated: animated)
    }

    private func scheduleCollapsedFrame(for scene: IslandScene, animated: Bool) {
        let key = ObjectIdentifier(scene)
        collapseTasks[key]?.cancel()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var delay: TimeInterval = 0
        if animated, !reduceMotion {
            delay = IslandTheme.collapseSettleDelay
        }
        let task = Task { @MainActor [weak self, weak scene] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled, let self, let scene else {
                return
            }
            guard !(self.model.isExpanded && self.activeScene === scene) else {
                return
            }
            self.collapseTasks.removeValue(forKey: key)
            self.applyCollapsedFrame(to: scene, resignKey: true)
        }
        collapseTasks[key] = task
    }

    private func cancelScheduledCollapse(for scene: IslandScene) {
        collapseTasks.removeValue(forKey: ObjectIdentifier(scene))?.cancel()
    }

    private func cancelScheduledCollapses() {
        for task in collapseTasks.values {
            task.cancel()
        }
        collapseTasks.removeAll()
    }

    private func schedulePeekReset(for scene: IslandScene) {
        let key = ObjectIdentifier(scene)
        peekResetTasks[key]?.cancel()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let delay: TimeInterval = reduceMotion ? 0 : IslandTheme.collapseSettleDelay
        let task = Task { @MainActor [weak self, weak scene] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled, let self, let scene else {
                return
            }
            self.peekResetTasks.removeValue(forKey: key)
            guard !scene.isPeeking,
                  !(self.model.isExpanded && self.activeScene === scene) else {
                return
            }
            scene.presenter.applyFrame(scene.collapsedLayout)
        }
        peekResetTasks[key] = task
    }

    private func cancelScheduledPeekReset(for scene: IslandScene) {
        peekResetTasks.removeValue(forKey: ObjectIdentifier(scene))?.cancel()
    }

    private func cancelScheduledPeekResets() {
        for task in peekResetTasks.values {
            task.cancel()
        }
        peekResetTasks.removeAll()
    }

    private func applyCollapsedFrame(to scene: IslandScene, resignKey: Bool) {
        guard !isSystemHidden else {
            return
        }
        guard scenes.contains(where: { $0 === scene }) else {
            return
        }
        scene.presenter.applyFrame(scene.isPeeking ? scene.peekLayout : scene.collapsedLayout)
        if resignKey {
            scene.presenter.resignKey()
        }
    }

    private func resetPeeking(for scene: IslandScene) {
        scene.setPeeking(false)
        cancelScheduledPeekReset(for: scene)
    }

    private func showAllCollapsed() {
        guard !isSystemHidden else {
            return
        }
        cancelHoverTimers()
        cancelScheduledCollapses()
        cancelScheduledPeekResets()
        model.isExpanded = false
        model.keyboardFocusVisible = false
        model.showsShelf = false
        model.showsPomodoro = false
        for scene in scenes {
            scene.setPeeking(false)
            scene.setActive(scene === activeScene)
            scene.presenter.show(layout: scene.collapsedLayout, makeKey: false)
            scene.presenter.resignKey()
        }
        updateFocusItems()
    }

    private func showInactiveScenesCollapsed(except scene: IslandScene) {
        for candidate in scenes where candidate !== scene {
            resetPeeking(for: candidate)
            candidate.setActive(false)
            candidate.presenter.show(layout: candidate.collapsedLayout, makeKey: false)
        }
    }

    private func collapseImmediatelyForExternalUI() {
        cancelHoverTimers()
        cancelScheduledCollapses()
        cancelScheduledPeekResets()
        model.isExpanded = false
        model.keyboardFocusVisible = false
        model.showsShelf = false
        model.showsPomodoro = false
        for scene in scenes {
            scene.setPeeking(false)
            scene.presenter.show(layout: scene.collapsedLayout, makeKey: false)
            scene.presenter.resignKey()
        }
    }

    // MARK: - Configuration

    private func observeConfiguration() {
        config.$settings
            .sink { [weak self] _ in
                // @Published emits in willSet; defer so imperative layout/appearance reads the committed value.
                DispatchQueue.main.async { self?.configurationDidChange() }
            }
            .store(in: &cancellables)

        config.$folders
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateFocusItems() }
            }
            .store(in: &cancellables)

        config.$launchItems
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateFocusItems() }
            }
            .store(in: &cancellables)

        config.$shelfItems
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateFocusItems() }
            }
            .store(in: &cancellables)
    }

    private func configurationDidChange() {
        IslandTheme.apply(config.settings.theme)
        for scene in scenes {
            applyAppearance(for: scene)
        }
        cancelHoverTimers()
        refreshLayouts()
        updateFocusItems()
    }

    private func refreshLayouts() {
        guard !isSystemHidden else {
            return
        }
        for scene in scenes {
            let collapsed = display.layout(
                expanded: false,
                showsTimer: pomodoro.isActive,
                on: scene.screen
            )
            let peek = display.layout(
                expanded: false,
                peeking: true,
                showsTimer: pomodoro.isActive,
                on: scene.screen
            )
            let expanded = display.layout(expanded: true, on: scene.screen)
            scene.update(
                screen: scene.screen,
                collapsed: collapsed,
                peek: peek,
                expanded: expanded
            )
            if scene === activeScene && model.isExpanded {
                scene.presenter.applyFrame(expanded)
            } else if scene.presenter.isVisible {
                scene.presenter.applyFrame(scene.isPeeking ? peek : collapsed)
            }
        }
    }

    private func updateFocusItems() {
        clampPageIndices()
        if model.result != nil {
            var items: [IslandFocusID] = [
                .resultCopy,
                .resultSave,
                .resultShare,
                .resultOCR,
                .resultRetake
            ]
            if model.result?.savedURL != nil {
                items.append(.resultReveal)
            }
            items.append(.resultClose)
            focusItems = items
        } else if model.showsShelf {
            var items: [IslandFocusID] = [.shelfAdd]
            items += config.shelfItems.map { .shelfItem($0.id) }
            if !config.shelfItems.isEmpty {
                items.append(.shelfClear)
            }
            items.append(.shelfBack)
            items.append(.collapse)
            focusItems = items
        } else if model.showsPomodoro {
            focusItems = [
                .pomodoroToggle,
                .pomodoroReset,
                .pomodoroSkip,
                .pomodoroBack,
                .collapse
            ]
        } else {
            var items: [IslandFocusID] = CaptureKind.allCases.map { .capture($0) }
            items.append(.record)
            items.append(.colorPicker)
            items += recentFiles.files.prefix(3).map { .recentFile($0.url) }

            let folderPage = ItemPage(config.folders, index: model.folderPage)
            for folder in folderPage.items {
                items.append(.folder(folder.id))
            }
            if config.folders.count < ConfigStore.homeItemCount {
                items.append(.addFolder)
            }
            if folderPage.count > 1 { items.append(.nextFolderPage) }

            let launchPage = ItemPage(config.launchItems, index: model.launchPage)
            for item in launchPage.items {
                items.append(.launch(item.id))
            }
            if config.launchItems.count < ConfigStore.homeItemCount {
                items.append(.addLaunch)
            }
            if config.launchItems.isEmpty { items.append(.addWebsite) }
            if launchPage.count > 1 { items.append(.nextLaunchPage) }

            items.append(.pomodoro)
            items.append(.shelf)
            items.append(.workspace)
            items.append(.collapse)
            focusItems = items
        }

        if let selected = model.selectedFocus, focusItems.contains(selected) {
            return
        }
        model.selectedFocus = focusItems.first
    }

    private func clampPageIndices() {
        let folderIndex = ItemPage(config.folders, index: model.folderPage).index
        if folderIndex != model.folderPage {
            model.folderPage = folderIndex
        }
        let launchIndex = ItemPage(config.launchItems, index: model.launchPage).index
        if launchIndex != model.launchPage {
            model.launchPage = launchIndex
        }
    }

    // MARK: - Keyboard

    private func handleKeyDown(on scene: IslandScene, event: NSEvent) -> Bool {
        guard scene === activeScene,
              model.isExpanded,
              !isCapturing,
              !isOnboardingOpen else {
            return false
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        if modifiers == .command {
            if model.result != nil {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c": copyResult(); return true
                case "s": saveResult(); return true
                case "t": recognizeResultText(); return true
                case "r":
                    if !model.isResultBusy, let kind = model.result?.kind { startCapture(kind) }
                    return true
                default: break
                }
            } else if let key = event.charactersIgnoringModifiers,
                      let number = Int(key) {
                if number == 5 {
                    startRegionRecording()
                    return true
                }
                if (1...CaptureKind.allCases.count).contains(number) {
                    startCapture(CaptureKind.allCases[number - 1])
                    return true
                }
            }
        }

        switch event.keyCode {
        case 53:
            if model.showsShelf {
                model.showsShelf = false
                updateFocusItems()
                model.selectedFocus = .shelf
                return true
            }
            if model.showsPomodoro {
                model.showsPomodoro = false
                updateFocusItems()
                model.selectedFocus = .pomodoro
                return true
            }
            if model.result != nil {
                model.clearResult()
                updateFocusItems()
            }
            model.dismissNotice()
            collapse(animated: true)
            return true

        case 48:
            guard modifiers.isEmpty else {
                return false
            }
            moveSelection(backward: event.modifierFlags.contains(.shift))
            return true

        case 123, 126:
            guard modifiers.isEmpty else {
                return false
            }
            moveSelection(backward: true)
            return true

        case 124, 125:
            guard modifiers.isEmpty else {
                return false
            }
            moveSelection(backward: false)
            return true

        case 36, 76, 49:
            guard modifiers.isEmpty else {
                return false
            }
            activateSelected()
            return true

        default:
            return false
        }
    }

    private func moveSelection(backward: Bool) {
        updateFocusItems()
        guard !focusItems.isEmpty else {
            return
        }
        model.keyboardFocusVisible = true
        let currentIndex = model.selectedFocus.flatMap { focusItems.firstIndex(of: $0) }
        let nextIndex: Int
        if let currentIndex {
            let offset = backward ? -1 : 1
            nextIndex = (currentIndex + offset + focusItems.count) % focusItems.count
        } else {
            nextIndex = 0
        }
        model.selectedFocus = focusItems[nextIndex]
    }

    private func activateSelected() {
        updateFocusItems()
        guard let focus = model.selectedFocus ?? focusItems.first else {
            return
        }
        model.keyboardFocusVisible = true

        switch focus {
        case .capture(let kind):
            startCapture(kind)
        case .record:
            startRegionRecording()
        case .shelf:
            model.showsShelf = true
            model.showsPomodoro = false
                        model.keyboardFocusVisible = false
            updateFocusItems()
            model.selectedFocus = focusItems.first
        case .shelfBack:
            model.showsShelf = false
            updateFocusItems()
            model.selectedFocus = .shelf
        case .pomodoro:
            togglePomodoro()
        case .pomodoroBack:
            model.showsPomodoro = false
            updateFocusItems()
            model.selectedFocus = .pomodoro
        case .pomodoroToggle:
            pomodoro.toggle()
        case .pomodoroReset:
            pomodoro.reset()
        case .pomodoroSkip:
            pomodoro.skip()
        case .recentFile(let url):
            openRecentFile(url)
        case .workspace:
            openWorkspace()
        case .colorPicker:
            sampleColor()
        case .shelfAdd:
            addShelfFiles()
        case .shelfItem(let id):
            openShelfItem(id)
        case .shelfClear:
            clearShelf()
        case .folder(let id):
            openFolder(id)
        case .addFolder:
            addFolders()
        case .manageFolders:
            openSettings(tab: .folders)
        case .launch(let id):
            openLaunch(id)
        case .addLaunch:
            addApplications()
        case .editLaunch:
            openSettings(tab: .launch)
        case .addWebsite:
            addWebsite()
        case .location(let location):
            openLocation(location)
        case .nextFolderPage:
            nextPage(folders: true)
        case .nextLaunchPage:
            nextPage(folders: false)
        case .resultRetake:
            if !model.isResultBusy, let kind = model.result?.kind { startCapture(kind) }
        case .collapse:
            collapse(animated: true)
        case .resultCopy:
            copyResult()
        case .resultSave:
            saveResult()
        case .resultShare:
            shareResult()
        case .resultOCR:
            recognizeResultText()
        case .resultReveal:
            revealResult()
        case .resultClose:
            closeResult(returnToTools: true)
        }
    }

    // MARK: - Hover

    private func hoverChanged(_ hovering: Bool, on scene: IslandScene) {
        guard !isCapturing, !model.isDropTargeted,
              !isSystemHidden,
              !isOnboardingOpen,
              !isPresentingCaptureResult,
              !display.isFullscreenActive(on: scene.screen) else {
            return
        }

        let isExpandedHere = model.isExpanded && activeScene === scene

        if hovering {
            cancelScheduledPeekReset(for: scene)
            if scene.style != .floating, !isExpandedHere, !scene.isPeeking {
                scene.setPeeking(true)
                scene.presenter.applyFrame(scene.peekLayout)
            }

            guard config.settings.trigger == .hover else {
                return
            }
            hoverArmed = true
            cancelHoverTimers()
            guard !isExpandedHere else {
                return
            }
            let delay = max(0.1, config.settings.hoverExpandDelay)
            let item = DispatchWorkItem { [weak self, weak scene] in
                guard let self, let scene,
                      self.config.settings.trigger == .hover,
                      !(self.model.isExpanded && self.activeScene === scene),
                      !self.display.isFullscreenActive(on: scene.screen) else {
                    return
                }
                self.expand(on: scene, makeKey: false)
            }
            hoverExpandWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
            hoverExpandWorkItem?.cancel()
            hoverExpandWorkItem = nil

            if scene.isPeeking {
                scene.setPeeking(false)
                schedulePeekReset(for: scene)
            }

            guard config.settings.trigger == .hover,
                  model.isExpanded,
                  activeScene === scene,
                  hoverArmed else {
                return
            }
            let delay = max(0.1, config.settings.hoverCollapseDelay)
            let item = DispatchWorkItem { [weak self, weak scene] in
                guard let self, let scene,
                      self.model.isExpanded,
                      self.activeScene === scene,
                      self.config.settings.trigger == .hover else {
                    return
                }
                self.collapse(animated: true)
            }
            hoverCollapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func cancelHoverTimers() {
        hoverExpandWorkItem?.cancel()
        hoverExpandWorkItem = nil
        hoverCollapseWorkItem?.cancel()
        hoverCollapseWorkItem = nil
    }

    // MARK: - Window lifecycle

    private func observeNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(sessionDidResignActive),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(sessionDidBecomeActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func sceneDidResignKey(_ scene: IslandScene) {
        guard scene === activeScene else {
            return
        }
        guard model.isExpanded,
              !isCapturing,
              suspensionCount == 0,
              !isOnboardingOpen,
              !isSystemHidden else {
            return
        }
        DispatchQueue.main.async { [weak self, weak scene] in
            guard let self, let scene,
                  scene === self.activeScene,
                  self.model.isExpanded,
                  !self.isCapturing,
                  self.suspensionCount == 0,
                  !self.isOnboardingOpen,
                  !self.isSystemHidden else {
                return
            }
            if self.scenes.contains(where: { $0 !== scene && $0.presenter.isKeyWindow }) {
                return
            }
            self.collapse(animated: true)
        }
    }

    private func handleGlobalMouseDown(at location: NSPoint) {
        guard statusBar?.containsScreenPoint(location) != true else {
            return
        }
        guard !isCapturing,
              suspensionCount == 0,
              !isOnboardingOpen,
              !isSystemHidden,
              !scenes.isEmpty else {
            return
        }

        let clickedScene = scene(at: location)

        if model.isExpanded {
            guard let expandedScene = activeScene else {
                return
            }
            if clickedScene === expandedScene {
                return
            }
            if let clickedScene {
                expand(on: clickedScene, makeKey: true)
            } else {
                collapse(animated: true)
            }
            return
        }

        if let clickedScene {
            expand(on: clickedScene, makeKey: true)
        }
    }

    @objc private func screenParametersDidChange() {
        Logger.island.info("Screen parameters changed")
        guard !isSystemHidden else {
            return
        }
        rebuildScenes(preferredDisplayID: activeScene?.displayID)
    }

    @objc private func sessionDidResignActive() {
        Logger.lifecycle.info("Session resigned active")
        hideForSystem()
    }

    @objc private func sessionDidBecomeActive() {
        Logger.lifecycle.info("Session became active")
        restoreFromSystem()
    }

    @objc private func systemWillSleep() {
        Logger.lifecycle.info("System will sleep")
        hideForSystem()
    }

    @objc private func systemDidWake() {
        Logger.lifecycle.info("System woke")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.restoreFromSystem()
        }
    }

    private var isScreenLocked: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    private func hideForSystem() {
        isSystemHidden = true
        cancelHoverTimers()
        cancelScheduledPeekResets()
        for scene in scenes {
            scene.presenter.hide()
        }
        if regionSelector.isSelecting {
            regionSelector.cancel()
        }
        if windowPicker.isPresenting {
            windowPicker.cancel()
        }
        if captureResultOverlay != nil {
            captureResultOverlay?.dismiss()
        }
        if isCapturing {
            scrollingCapture.cancel()
            regionRecording.cancel()
        }
        captureTask?.cancel()
    }

    private func restoreFromSystem() {
        if isScreenLocked {
            return
        }
        isSystemHidden = false
        guard !isCapturing, !isOnboardingOpen else {
            return
        }
        rebuildScenes(preferredDisplayID: activeScene?.displayID)
    }

    // MARK: - Pomodoro

    private func configurePomodoro() {
        pomodoro.onPhaseCompleted = { [weak self] phase in
            guard let self else {
                return
            }
            NSSound(named: "Glass")?.play()
            let message = phase == .focus ? "专注完成，休息 5 分钟" : "休息结束，继续专注"
            self.model.showNotice(IslandNotice(kind: .success, message: message))
            self.updateFocusItems()
        }
        pomodoro.$isActive
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshLayouts()
                }
            }
            .store(in: &cancellables)

        recentFiles.$files
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.model.isExpanded, !self.model.showsPomodoro else {
                        return
                    }
                    self.updateFocusItems()
                }
            }
            .store(in: &cancellables)
    }

    private func togglePomodoro() {
        guard !isCapturing, !isSystemHidden else {
            return
        }
        model.showsPomodoro.toggle()
        if model.showsPomodoro {
            model.showsShelf = false
        }
        model.keyboardFocusVisible = false
        updateFocusItems()
        model.selectedFocus = model.showsPomodoro ? focusItems.first : .pomodoro
    }

    // MARK: - Recent files

    private func openRecentFile(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            presentNotice(
                IslandNotice(
                    kind: .error,
                    message: "文件已不存在：\(url.lastPathComponent)"
                )
            )
            recentFiles.load(force: true)
            return
        }
        if NSWorkspace.shared.open(url) {
            collapse(animated: true)
        } else {
            presentNotice(
                IslandNotice(
                    kind: .error,
                    message: "无法打开 \(url.lastPathComponent)"
                )
            )
        }
    }

    // MARK: - Color picker

    private func sampleColor() {
        guard !isCapturing, !isSystemHidden, colorSampler == nil else {
            return
        }
        beginSuspension()
        let sampler = NSColorSampler()
        colorSampler = sampler
        sampler.show { [weak self] color in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.colorSampler = nil
                self.endSuspension()
                guard let color,
                      let converted = color.usingColorSpace(.sRGB) else {
                    self.restoreKeyIfPossible()
                    return
                }
                let red = Int((converted.redComponent * 255).rounded())
                let green = Int((converted.greenComponent * 255).rounded())
                let blue = Int((converted.blueComponent * 255).rounded())
                let hex = String(format: "#%02X%02X%02X", red, green, blue)
                let rgb = "rgb(\(red), \(green), \(blue))"
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                guard pasteboard.setString("\(hex)\n\(rgb)", forType: .string) else {
                    self.presentNotice(IslandNotice(kind: .error, message: "复制颜色失败"))
                    return
                }
                self.presentNotice(IslandNotice(kind: .success, message: "已复制 \(hex)"))
            }
        }
    }

    // MARK: - Shortcut

    private func registerShortcut() {
        KeyboardShortcuts.onKeyUp(for: .toggleIsland) { [weak self] in
            self?.toggleIsland()
        }
        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak self] in
            self?.startCapture(.region)
        }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [weak self] in
            self?.startCapture(.window)
        }
        KeyboardShortcuts.onKeyUp(for: .captureDisplay) { [weak self] in
            self?.startCapture(.display)
        }
        KeyboardShortcuts.onKeyUp(for: .captureScrolling) { [weak self] in
            self?.startScrollingCapture()
        }
        KeyboardShortcuts.onKeyUp(for: .recordRegion) { [weak self] in
            self?.startRegionRecording()
        }
        KeyboardShortcuts.onKeyUp(for: .sampleColor) { [weak self] in
            self?.sampleColor()
        }
    }

    // MARK: - Folders and launch items

    private func openFolder(_ id: UUID) {
        guard let folder = config.folders.first(where: { $0.id == id }) else {
            return
        }

        switch WorkspaceService.openFolder(id: id, config: config) {
        case .success:
            Logger.folders.info("Open folder succeeded")
            collapse(animated: true)

        case .failure(let error):
            Logger.folders.error("Open folder failed: \(String(describing: error), privacy: .public)")
            showFolderError(error, folder: folder)
        }
    }

    private func showFolderError(_ error: WorkspaceService.FolderOpenError, folder: FavoriteFolder) {
        var actions: [IslandNotice.Action] = []
        let folderID = folder.id
        let title = folder.title

        switch error {
        case .missingVolume:
            actions = [
                .init(title: "重试", style: .standard) { [weak self] in
                    self?.openFolder(folderID)
                },
                .init(title: "重新选择", style: .standard) { [weak self] in
                    self?.relocateFolder(folderID)
                }
            ]
        case .missing:
            actions = [
                .init(title: "重新选择", style: .standard) { [weak self] in
                    self?.relocateFolder(folderID)
                },
                .init(title: "移除", style: .destructive) { [weak self] in
                    self?.removeFolder(folderID, title: title)
                }
            ]
        case .permissionDenied:
            actions = [
                .init(title: "重新选择", style: .standard) { [weak self] in
                    self?.relocateFolder(folderID)
                }
            ]
        case .unresolved:
            actions = [
                .init(title: "重新选择", style: .standard) { [weak self] in
                    self?.relocateFolder(folderID)
                },
                .init(title: "移除", style: .destructive) { [weak self] in
                    self?.removeFolder(folderID, title: title)
                }
            ]
        case .openFailed:
            actions = [
                .init(title: "重试", style: .standard) { [weak self] in
                    self?.openFolder(folderID)
                }
            ]
        }

        presentNotice(
            IslandNotice(
                kind: .error,
                message: "「\(title)」\(error.localizedDescription)",
                actions: actions
            )
        )
    }

    private func removeFolder(_ id: UUID, title: String) {
        config.removeFolder(id: id)
        updateFocusItems()
        model.showNotice(IslandNotice(kind: .success, message: "已移除「\(title)」的快捷入口"))
    }

    private func relocateFolder(_ id: UUID) {
        guard let folder = config.folders.first(where: { $0.id == id }) else {
            return
        }

        beginSuspension()
        let url = SystemPanels.chooseDirectory(
            message: "为「\(folder.title)」选择新的位置",
            prompt: "重新定位"
        )
        endSuspension()

        guard let url else {
            restoreKeyIfPossible()
            return
        }

        do {
            try config.relocateFolder(id: id, to: url)
            updateFocusItems()
            model.showNotice(IslandNotice(kind: .success, message: "已重新定位「\(folder.title)」"))
        } catch {
            model.showNotice(
                IslandNotice(
                    kind: .error,
                    message: error.localizedDescription
                )
            )
        }
        restoreKeyIfPossible()
    }

    private func addFolders() {
        let remaining = ConfigStore.maxFolderCount - config.folders.count
        guard remaining > 0 else {
            presentNotice(IslandNotice(kind: .error, message: ConfigStoreError.folderLimitReached.localizedDescription))
            return
        }

        beginSuspension()
        let urls = SystemPanels.chooseDirectories(
            limit: remaining,
            message: "选择要固定的文件夹（可在工具栏翻页访问）"
        )
        endSuspension()

        guard !urls.isEmpty else {
            restoreKeyIfPossible()
            return
        }

        var added = 0
        var duplicates = 0
        var failed = 0
        for url in urls {
            do {
                try config.addFolder(at: url)
                added += 1
            } catch ConfigStoreError.duplicateFolder {
                duplicates += 1
            } catch {
                failed += 1
            }
        }
        updateFocusItems()

        if added > 0 {
            var message = "已固定 \(added) 个文件夹"
            if duplicates > 0 {
                message += "，\(duplicates) 个已存在"
            }
            if failed > 0 {
                message += "，\(failed) 个添加失败"
            }
            model.showNotice(IslandNotice(kind: .success, message: message))
        } else if duplicates > 0 {
            model.showNotice(IslandNotice(kind: .info, message: "所选文件夹已经固定过了"))
        } else if failed > 0 {
            model.showNotice(IslandNotice(kind: .error, message: "没有添加成功，请重新选择文件夹"))
        } else if !urls.isEmpty {
            model.showNotice(IslandNotice(kind: .error, message: ConfigStoreError.folderLimitReached.localizedDescription))
        }
        restoreKeyIfPossible()
    }

    private func openLaunch(_ id: UUID) {
        guard let item = config.launchItems.first(where: { $0.id == id }) else {
            return
        }

        switch WorkspaceService.openLaunchItem(item) {
        case .success:
            Logger.launch.info("Open launch item succeeded kind=\(item.kind.rawValue, privacy: .public)")
            collapse(animated: true)

        case .failure(let error):
            Logger.launch.error("Open launch item failed: \(String(describing: error), privacy: .public)")
            var actions: [IslandNotice.Action] = []
            if case .missingApplication = error {
                actions.append(
                    .init(title: "移除", style: .destructive) { [weak self] in
                        self?.config.removeLaunchItem(id: id)
                        self?.updateFocusItems()
                        self?.model.showNotice(
                            IslandNotice(kind: .success, message: "已移除「\(item.title)」")
                        )
                    }
                )
            } else {
                actions.append(
                    .init(title: "重试", style: .standard) { [weak self] in
                        self?.openLaunch(id)
                    }
                )
            }
            presentNotice(
                IslandNotice(
                    kind: .error,
                    message: "无法启动「\(item.title)」：\(error.localizedDescription)",
                    actions: actions
                )
            )
        }
    }

    private func restoreKeyIfPossible() {
        guard model.isExpanded,
              let scene = activeScene,
              scene.presenter.isVisible,
              !isSystemHidden else {
            return
        }
        expand(on: scene, makeKey: true)
    }

    // MARK: - Quick access and direct pinning

    private func openLocation(_ location: QuickLocation) {
        if NSWorkspace.shared.open(location.url) {
            collapse(animated: true)
        } else {
            presentNotice(IslandNotice(kind: .error, message: "无法打开“\(location.title)”，请在 Finder 中检查位置。"))
        }
    }

    private func nextPage(folders: Bool) {
        if folders {
            let page = ItemPage(config.folders, index: model.folderPage)
            model.folderPage = (page.index + 1) % page.count
        } else {
            let page = ItemPage(config.launchItems, index: model.launchPage)
            model.launchPage = (page.index + 1) % page.count
        }
        updateFocusItems()
        model.selectedFocus = folders ? .nextFolderPage : .nextLaunchPage
    }

    private func pinURLs(_ urls: [URL]) -> Bool {
        guard !isCapturing, !isOnboardingOpen, !urls.isEmpty else { return false }
        model.isDropTargeted = false

        let considered = Array(urls.prefix(32))
        let pinnable = considered.filter(isPinnable)
        let shelfCandidates = considered.filter { !isPinnable($0) }

        let result = config.importPins(from: pinnable)
        let shelfResult = shelfCandidates.isEmpty ? nil : config.addShelfItems(at: shelfCandidates)

        if result.folders > 0 { model.folderPage = max(0, (config.folders.count - 1) / ConfigStore.homeItemCount) }
        if result.launchItems > 0 { model.launchPage = max(0, (config.launchItems.count - 1) / ConfigStore.homeItemCount) }
        if let shelfResult, shelfResult.added > 0, result.added == 0 {
            model.showsShelf = true
        }
        updateFocusItems()

        var parts: [String] = []
        if result.added > 0 { parts.append("已固定 \(result.added) 项") }
        if let shelfResult, shelfResult.added > 0 { parts.append("已暂存 \(shelfResult.added) 个文件") }
        if result.duplicates > 0 { parts.append("\(result.duplicates) 项已存在") }
        if let shelfResult, shelfResult.duplicates > 0 { parts.append("\(shelfResult.duplicates) 个文件已在暂存") }
        if let shelfResult, shelfResult.limitReached { parts.append("暂存已满，最多 \(ConfigStore.maxShelfItemCount) 项") }
        if result.rejected > 0 { parts.append("\(result.rejected) 项未添加") }
        if let shelfResult, shelfResult.rejected > 0, !shelfResult.limitReached {
            parts.append("\(shelfResult.rejected) 个文件无法暂存")
        }
        if urls.count > 32 { parts.append("单次最多处理 32 项") }

        let added = result.added + (shelfResult?.added ?? 0)
        let duplicates = result.duplicates + (shelfResult?.duplicates ?? 0)
        let rejected = result.rejected + (shelfResult?.rejected ?? 0)
        let kind: IslandNotice.Kind = added > 0 ? .success : (duplicates > 0 ? .info : .error)
        if parts.isEmpty { parts.append(rejected > 0 ? "没有可添加的内容" : "没有检测到内容") }
        presentNotice(IslandNotice(kind: kind, message: parts.joined(separator: "；")))
        return added > 0 || duplicates > 0
    }

    private func isPinnable(_ url: URL) -> Bool {
        if url.isFileURL {
            if url.pathExtension.lowercased() == "app" {
                return true
            }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return values?.isDirectory == true && values?.isPackage != true
        }
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    // MARK: - Shelf

    private func toggleShelf() {
        guard !isCapturing, !isSystemHidden else {
            return
        }
        model.showsShelf.toggle()
        if model.showsShelf {
            model.showsPomodoro = false
                    }
        model.keyboardFocusVisible = false
        updateFocusItems()
        model.selectedFocus = model.showsShelf ? focusItems.first : .shelf
    }

    @discardableResult
    private func stageShelfFiles(_ urls: [URL], switchToShelf: Bool) -> Bool {
        guard !isCapturing, !isOnboardingOpen, !urls.isEmpty else {
            return false
        }

        model.isDropTargeted = false
        let result = config.addShelfItems(at: urls)
        if result.added > 0, switchToShelf {
            model.showsShelf = true
        }
        updateFocusItems()

        let message: String
        let kind: IslandNotice.Kind
        if result.added > 0 {
            var parts = ["已暂存 \(result.added) 项"]
            if result.duplicates > 0 { parts.append("\(result.duplicates) 项已存在") }
            if result.rejected > 0 { parts.append("\(result.rejected) 项未添加") }
            message = parts.joined(separator: "；")
            kind = .success
        } else if result.duplicates > 0 {
            message = "所选项目已在暂存中"
            kind = .info
        } else if result.limitReached {
            message = "暂存已满，最多 \(ConfigStore.maxShelfItemCount) 项"
            kind = .error
        } else {
            message = "没有可暂存的内容"
            kind = .error
        }

        presentNotice(IslandNotice(kind: kind, message: message))
        return result.added > 0 || result.duplicates > 0
    }

    private func shelfDrop(_ urls: [URL]) -> Bool {
        stageShelfFiles(urls, switchToShelf: true)
    }

    private func addShelfFiles() {
        let remaining = ConfigStore.maxShelfItemCount - config.shelfItems.count
        guard remaining > 0 else {
            presentNotice(
                IslandNotice(
                    kind: .error,
                    message: "暂存已满，最多 \(ConfigStore.maxShelfItemCount) 项"
                )
            )
            return
        }

        beginSuspension()
        NSApp.activate(ignoringOtherApps: true)
        let urls = SystemPanels.chooseStagingFiles(limit: remaining)
        endSuspension()

        guard !urls.isEmpty else {
            restoreKeyIfPossible()
            return
        }
        _ = stageShelfFiles(urls, switchToShelf: true)
        restoreKeyIfPossible()
    }

    private func openShelfItem(_ id: UUID) {
        guard let item = config.shelfItems.first(where: { $0.id == id }) else {
            return
        }
        guard let url = existingShelfURL(id: id, title: item.title) else {
            return
        }
        if NSWorkspace.shared.open(url) {
            collapse(animated: true)
        } else {
            presentNotice(IslandNotice(kind: .error, message: "无法打开「\(item.title)」"))
        }
    }

    private func revealShelfItem(_ id: UUID) {
        guard let item = config.shelfItems.first(where: { $0.id == id }) else {
            return
        }
        guard let url = existingShelfURL(id: id, title: item.title) else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        collapse(animated: true)
    }

    private func copyShelfPath(_ id: UUID) {
        guard let item = config.shelfItems.first(where: { $0.id == id }),
              let url = config.resolveShelfItem(id: id) else {
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
        model.showNotice(IslandNotice(kind: .success, message: "已复制「\(item.title)」的路径"))
    }

    private func shareShelfItem(_ id: UUID) {
        guard let url = config.resolveShelfItem(id: id) else {
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            presentNotice(IslandNotice(kind: .error, message: "文件已不存在，无法分享"))
            return
        }
        let window = NSApp.keyWindow ?? activeScene?.presenter.panelWindow
        guard let view = window?.contentView else {
            return
        }
        let picker = NSSharingServicePicker(items: [url])
        shelfSharePicker = picker
        let mouse = window?.mouseLocationOutsideOfEventStream
            ?? NSPoint(x: view.bounds.midX, y: view.bounds.midY)
        let point = view.convert(mouse, from: nil)
        picker.show(
            relativeTo: NSRect(x: point.x, y: point.y, width: 1, height: 1),
            of: view,
            preferredEdge: .minY
        )
    }

    private func removeShelfItem(_ id: UUID) {
        guard let item = config.shelfItems.first(where: { $0.id == id }) else {
            return
        }
        config.removeShelfItem(id: id)
        updateFocusItems()
        model.showNotice(IslandNotice(kind: .success, message: "已从暂存移除「\(item.title)」"))
    }

    private func clearShelf() {
        guard !config.shelfItems.isEmpty else {
            return
        }
        let count = config.shelfItems.count
        config.clearShelf()
        updateFocusItems()
        model.showNotice(IslandNotice(kind: .success, message: "已清空 \(count) 项暂存，原文件未受影响"))
    }

    private func existingShelfURL(id: UUID, title: String) -> URL? {
        guard let url = config.resolveShelfItem(id: id),
              FileManager.default.fileExists(atPath: url.path) else {
            presentNotice(
                IslandNotice(
                    kind: .error,
                    message: "「\(title)」已不在原位置",
                    actions: [
                        .init(title: "移除", style: .destructive) { [weak self] in
                            self?.removeShelfItem(id)
                        }
                    ]
                )
            )
            return nil
        }
        return url
    }

    private func addApplications() {
        let remaining = ConfigStore.maxLaunchItemCount - config.launchItems.count
        guard remaining > 0 else {
            presentNotice(IslandNotice(kind: .error, message: ConfigStoreError.launchLimitReached.localizedDescription))
            return
        }
        beginSuspension()
        NSApp.activate(ignoringOtherApps: true)
        let urls = SystemPanels.chooseApplications(limit: remaining)
        endSuspension()
        if !urls.isEmpty { _ = pinURLs(urls) }
        restoreKeyIfPossible()
    }

    private func addWebsite() {
        guard config.launchItems.count < ConfigStore.maxLaunchItemCount else {
            presentNotice(IslandNotice(kind: .error, message: ConfigStoreError.launchLimitReached.localizedDescription))
            return
        }
        beginSuspension()
        NSApp.activate(ignoringOtherApps: true)
        let value = SystemPanels.website(title: "固定网页", message: "输入常用网址，下次展开即可打开。", initialTitle: "", initialURL: "")
        endSuspension()
        if let value {
            do {
                try config.addWebsite(title: value.title, urlString: value.urlString)
                model.launchPage = max(0, (config.launchItems.count - 1) / ConfigStore.homeItemCount)
                updateFocusItems()
                model.showNotice(IslandNotice(kind: .success, message: "已固定网页"))
            } catch {
                presentNotice(IslandNotice(kind: .error, message: error.localizedDescription))
            }
        }
        restoreKeyIfPossible()
    }

    // MARK: - Capture

    func startCapture(_ kind: CaptureKind) {
        guard let scene = activeScene ?? sceneUnderMouse() else {
            return
        }
        startCapture(kind, from: scene)
    }

    private func startCapture(_ kind: CaptureKind, from scene: IslandScene) {
        guard !isCapturing,
              !isSystemHidden,
              !isOnboardingOpen,
              !isPresentingCaptureResult else {
            return
        }
        dismissRecordingResultHUD()

        if kind == .scrolling {
            startScrollingCapture(from: scene)
            return
        }

        isCapturing = true
        captureScene = scene
        activate(scene)
        beginSuspension()
        cancelHoverTimers()
        model.showsShelf = false
        model.showsPomodoro = false
        model.dismissNotice()

        captureTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.performCapture(kind)
        }
    }

    private func performCapture(_ kind: CaptureKind) async {
        defer {
            isCapturing = false
            captureScene = nil
            captureTask = nil
            endSuspension()
        }

        if !ScreenPermissionService.isGranted {
            let granted = ScreenPermissionService.request()
            guard granted, ScreenPermissionService.isGranted else {
                showPermissionNotice()
                return
            }
        }

        guard let screen = captureScene?.screen ?? sceneUnderMouse()?.screen else {
            handleCaptureError(.displayUnavailable, kind: kind)
            return
        }

        for scene in scenes {
            scene.presenter.hide()
        }
        try? await Task.sleep(nanoseconds: 70_000_000)

        guard !Task.isCancelled else {
            restoreAfterCapture()
            return
        }

        do {
            switch kind {
            case .region:
                guard let rect = await regionSelector.select(on: screen) else {
                    restoreAfterCapture()
                    return
                }
                guard !Task.isCancelled else {
                    restoreAfterCapture()
                    return
                }
                try? await Task.sleep(nanoseconds: 40_000_000)
                let image = try await captureService.captureRegion(rect, on: screen)
                let overlayRect = CGRect(
                    x: rect.minX,
                    y: screen.frame.height - rect.maxY,
                    width: rect.width,
                    height: rect.height
                )
                presentCaptureResult(
                    image,
                    kind: kind,
                    sourceTitle: screen.displayName,
                    screen: screen,
                    resultRect: overlayRect
                )

            case .window:
                let windows = try await captureService.availableWindows()
                guard !windows.isEmpty else {
                    throw CaptureError.noWindows
                }
                guard let window = await windowPicker.pick(
                    from: windows,
                    on: screen,
                    service: captureService
                ) else {
                    restoreAfterCapture()
                    return
                }
                guard !Task.isCancelled else {
                    restoreAfterCapture()
                    return
                }
                let image = try await captureService.captureWindow(window)
                let title = window.owningApplication?.applicationName
                let geometry = overlayGeometry(for: window, fallbackScreen: screen)
                presentCaptureResult(
                    image,
                    kind: .window,
                    sourceTitle: title,
                    screen: geometry.screen,
                    resultRect: geometry.rect
                )

            case .display:
                let image = try await captureService.captureDisplay(screen)
                presentCaptureResult(
                    image,
                    kind: kind,
                    sourceTitle: screen.displayName,
                    screen: screen,
                    resultRect: CGRect(origin: .zero, size: screen.frame.size)
                )

            case .scrolling:
                restoreAfterCapture()
            }
        } catch is CancellationError {
            restoreAfterCapture()
        } catch let error as CaptureError {
            handleCaptureError(error, kind: kind)
        } catch {
            handleCaptureError(.captureFailed, kind: kind)
        }
    }

    // MARK: - Scrolling capture and region recording

    func startScrollingCapture() {
        guard let scene = activeScene ?? sceneUnderMouse() else {
            return
        }
        startScrollingCapture(from: scene)
    }

    func startRegionRecording() {
        guard let scene = activeScene ?? sceneUnderMouse() else {
            return
        }
        startRegionRecording(from: scene)
    }

    private func startScrollingCapture(from scene: IslandScene) {
        guard !isCapturing, !isSystemHidden, !isOnboardingOpen, !isPresentingCaptureResult else {
            return
        }
        dismissRecordingResultHUD()

        isCapturing = true
        captureScene = scene
        activate(scene)
        beginSuspension()
        cancelHoverTimers()
        model.showsShelf = false
        model.showsPomodoro = false
        model.dismissNotice()

        captureTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                self.isCapturing = false
                self.captureScene = nil
                self.captureTask = nil
                self.endSuspension()
            }

            guard self.ensureScreenPermission() else {
                self.showPermissionNotice()
                return
            }

            let screen = scene.screen
            for item in self.scenes {
                item.presenter.hide()
            }
            try? await Task.sleep(nanoseconds: 70_000_000)

            guard !Task.isCancelled else {
                self.restoreAfterCapture()
                return
            }
            guard let rect = await self.regionSelector.select(
                on: screen,
                hint: "拖动框选后缓慢滚动，自动拼接 · Esc 取消"
            ) else {
                self.restoreAfterCapture()
                return
            }
            guard !Task.isCancelled else {
                self.restoreAfterCapture()
                return
            }
            try? await Task.sleep(nanoseconds: 80_000_000)

            let image = await self.scrollingCapture.run(region: rect, on: screen)
            guard !Task.isCancelled else {
                self.restoreAfterCapture()
                return
            }
            guard let image else {
                self.restoreAfterCapture()
                self.model.showNotice(IslandNotice(kind: .info, message: "滚动截屏已取消"))
                return
            }
            self.presentCaptureResult(image, kind: .scrolling, sourceTitle: screen.displayName, screen: screen)
        }
    }

    private func startRegionRecording(from scene: IslandScene) {
        guard !isCapturing, !isSystemHidden, !isOnboardingOpen, !isPresentingCaptureResult else {
            return
        }
        dismissRecordingResultHUD()

        isCapturing = true
        captureScene = scene
        activate(scene)
        beginSuspension()
        cancelHoverTimers()
        model.showsShelf = false
        model.showsPomodoro = false
        model.dismissNotice()

        captureTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                self.isCapturing = false
                self.captureScene = nil
                self.captureTask = nil
                self.endSuspension()
            }

            guard self.ensureScreenPermission() else {
                self.showPermissionNotice()
                return
            }

            let screen = scene.screen
            for item in self.scenes {
                item.presenter.hide()
            }
            try? await Task.sleep(nanoseconds: 70_000_000)

            guard !Task.isCancelled else {
                self.restoreAfterCapture()
                return
            }
            guard let rect = await self.regionSelector.select(
                on: screen,
                hint: "拖动选择录制区域 · Esc 取消"
            ) else {
                self.restoreAfterCapture()
                return
            }
            guard !Task.isCancelled else {
                self.restoreAfterCapture()
                return
            }
            try? await Task.sleep(nanoseconds: 80_000_000)

            do {
                let url = try await self.regionRecording.run(
                    region: rect,
                    on: screen,
                    directory: self.existingDirectory(at: self.config.settings.recordingDirectoryPath)
                )
                guard !Task.isCancelled else {
                    self.restoreAfterCapture()
                    return
                }
                self.presentRecordingResult(url, on: screen)
            } catch is CancellationError {
                self.restoreAfterCapture()
                self.model.showNotice(IslandNotice(kind: .info, message: "已取消录屏"))
            } catch {
                self.restoreAfterCapture()
                self.presentNotice(
                    IslandNotice(
                        kind: .error,
                        message: error.localizedDescription,
                        actions: [
                            .init(title: "重试", style: .standard) { [weak self] in
                                self?.startRegionRecording()
                            }
                        ]
                    )
                )
            }
        }
    }

    private func ensureScreenPermission() -> Bool {
        if ScreenPermissionService.isGranted {
            return true
        }
        let granted = ScreenPermissionService.request()
        return granted && ScreenPermissionService.isGranted
    }

    private func presentRecordingResult(_ url: URL, on screen: NSScreen) {
        dismissRecordingResultHUD()
        let hud = CaptureHUDController()
        recordingResultHUD = hud
        let folder = FileManager.default.displayName(atPath: url.deletingLastPathComponent().path)
        hud.show(
            on: screen,
            kind: .saved,
            title: "录屏已保存到「\(folder)」",
            detail: url.lastPathComponent,
            actionTitle: "显示",
            onFinish: { [weak self] in
                NSWorkspace.shared.activateFileViewerSelecting([url])
                hud.dismiss()
                self?.recordingResultHUD = nil
            },
            onCancel: { [weak self] in
                hud.dismiss()
                self?.recordingResultHUD = nil
            }
        )
    }

    private func dismissRecordingResultHUD() {
        recordingResultHUD?.dismiss()
        recordingResultHUD = nil
    }

    private func existingDirectory(at path: String?) -> URL? {
        guard let path, !path.isEmpty else {
            return nil
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func presentCaptureResult(
        _ image: CGImage,
        kind: CaptureKind,
        sourceTitle: String?,
        screen: NSScreen? = nil,
        resultRect: CGRect? = nil
    ) {
        guard !isSystemHidden else {
            return
        }

        if kind == .scrolling,
           let screen,
           NSScreen.screens.contains(where: { $0 === screen }) {
            let geometry = scrollingPreviewGeometry(for: image, on: screen)
            presentCaptureOverlay(
                image,
                sourceTitle: sourceTitle,
                screen: screen,
                resultRect: geometry.viewport,
                contentSize: geometry.contentSize
            )
            return
        }

        if kind != .scrolling,
           let screen,
           let resultRect,
           NSScreen.screens.contains(where: { $0 === screen }) {
            presentCaptureOverlay(
                image,
                sourceTitle: sourceTitle,
                screen: screen,
                resultRect: resultRect
            )
            return
        }

        guard let scene = captureScene ?? activeScene,
              scenes.contains(where: { $0 === scene }) else {
            return
        }
        model.result = ScreenshotResult(
            image: image,
            kind: kind,
            sourceTitle: sourceTitle
        )
        model.isResultBusy = false
        model.dismissNotice()
        hoverArmed = false
        updateFocusItems()
        model.selectedFocus = .resultCopy
        showInactiveScenesCollapsed(except: scene)
        expand(on: scene, makeKey: true)

        if config.settings.captureOutputMode == .autoCopy {
            copyResult(isAutomatic: true)
        }
    }

    private func presentCaptureOverlay(
        _ image: CGImage,
        sourceTitle: String?,
        screen: NSScreen,
        resultRect: CGRect,
        contentSize: CGSize? = nil
    ) {
        let overlay = CaptureResultOverlayController(
            image: image,
            screen: screen,
            imageRect: resultRect,
            contentSize: contentSize,
            sourceTitle: sourceTitle,
            autoCopy: config.settings.captureOutputMode == .autoCopy,
            defaultDirectory: existingDirectory(at: config.settings.screenshotDirectoryPath),
            saveWithoutPrompt: config.settings.screenshotSaveWithoutPrompt
        )
        overlay.onClose = { [weak self] in
            DispatchQueue.main.async {
                self?.captureResultOverlayDidClose()
            }
        }
        overlay.onPin = { [weak self] rendered in
            guard let self else {
                return
            }
            self.pinCapture(
                rendered,
                on: screen,
                anchor: resultRect.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)
            )
        }
        captureResultOverlay = overlay
        isPresentingCaptureResult = true
        overlay.present()
    }

    private func pinCapture(_ image: CGImage, on screen: NSScreen, anchor: CGRect) {
        let pin = CapturePinController(image: image, screen: screen, anchor: anchor)
        pin.onClose = { [weak self, weak pin] in
            guard let self, let pin else {
                return
            }
            self.pinnedCaptures.removeAll { $0 === pin }
        }
        pinnedCaptures.append(pin)
        pin.show()
    }

    private func captureResultOverlayDidClose() {
        guard isPresentingCaptureResult else {
            return
        }
        isPresentingCaptureResult = false
        captureResultOverlay = nil
        restoreAfterCapture()
    }

    private func scrollingPreviewGeometry(
        for image: CGImage,
        on screen: NSScreen
    ) -> (viewport: CGRect, contentSize: CGSize) {
        let scale = max(1, screen.backingScaleFactor)
        let natural = CGSize(
            width: CGFloat(image.width) / scale,
            height: CGFloat(image.height) / scale
        )
        let horizontalMargin: CGFloat = 16
        let topMargin: CGFloat = 16
        let bottomReserve: CGFloat = 92
        let maxWidth = max(1, screen.frame.width - horizontalMargin * 2)
        let maxHeight = max(120, screen.frame.height - topMargin - bottomReserve)
        let widthScale = min(1, maxWidth / max(natural.width, 1))
        let contentSize = CGSize(
            width: natural.width * widthScale,
            height: natural.height * widthScale
        )
        let viewportHeight = min(contentSize.height, maxHeight)
        let viewport = CGRect(
            x: (screen.frame.width - contentSize.width) / 2,
            y: bottomReserve + (maxHeight - viewportHeight) / 2,
            width: contentSize.width,
            height: viewportHeight
        )
        return (viewport, contentSize)
    }

    private func overlayGeometry(
        for window: SCWindow,
        fallbackScreen: NSScreen
    ) -> (screen: NSScreen, rect: CGRect) {        let cgFrame = window.frame
        let primaryMaxY = (NSScreen.screens.first(where: { $0.frame.origin == .zero })
            ?? NSScreen.screens.first)?.frame.maxY ?? 0
        let appKitFrame = CGRect(
            x: cgFrame.minX,
            y: primaryMaxY - cgFrame.maxY,
            width: cgFrame.width,
            height: cgFrame.height
        )

        var target = fallbackScreen
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(appKitFrame)
            guard !intersection.isNull else {
                continue
            }
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                target = screen
            }
        }

        var rect = appKitFrame.offsetBy(dx: -target.frame.minX, dy: -target.frame.minY)
        let margin: CGFloat = 12
        let maxWidth = max(1, target.frame.width - margin * 2)
        let maxHeight = max(1, target.frame.height - margin * 2)
        if rect.width > maxWidth || rect.height > maxHeight {
            let scale = min(maxWidth / max(rect.width, 1), maxHeight / max(rect.height, 1))
            let width = rect.width * scale
            let height = rect.height * scale
            rect.origin.x += (rect.width - width) / 2
            rect.origin.y += (rect.height - height) / 2
            rect.size = CGSize(width: width, height: height)
        }
        rect.origin.x = min(
            max(rect.minX, margin),
            max(margin, target.frame.width - rect.width - margin)
        )
        rect.origin.y = min(
            max(rect.minY, margin),
            max(margin, target.frame.height - rect.height - margin)
        )
        return (target, rect)
    }

    private func restoreAfterCapture() {
        guard !isSystemHidden else {
            return
        }
        showAllCollapsed()
    }

    private func showPermissionNotice() {
        let notice = IslandNotice(
            kind: .error,
            message: "需要屏幕录制权限才能截屏。授权后请重新启动栖岛。",
            actions: [
                .init(title: "打开系统设置", style: .standard) {
                    ScreenPermissionService.openSystemSettings()
                },
                .init(title: "重新启动", style: .standard) {
                    ScreenPermissionService.relaunch()
                }
            ]
        )
        presentNotice(notice)
    }

    private func handleCaptureError(_ error: CaptureError, kind: CaptureKind) {
        guard !isSystemHidden else {
            return
        }

        if case .permissionDenied = error {
            showPermissionNotice()
            return
        }

        var actions: [IslandNotice.Action] = []
        if case .noWindows = error {
            actions = []
        } else {
            actions = [
                .init(title: "重试", style: .standard) { [weak self] in
                    self?.startCapture(kind)
                }
            ]
        }

        presentNotice(
            IslandNotice(
                kind: .error,
                message: error.localizedDescription,
                actions: actions
            )
        )
    }

    private func presentNotice(_ notice: IslandNotice) {
        model.showNotice(notice)
        guard !isSystemHidden, !isOnboardingOpen else {
            return
        }
        guard let scene = captureScene ?? activeScene,
              scenes.contains(where: { $0 === scene }) else {
            return
        }
        if !(model.isExpanded && activeScene === scene) {
            showInactiveScenesCollapsed(except: scene)
            expand(on: scene, makeKey: true)
        }
    }

    private func copyResult(isAutomatic: Bool = false) {
        guard let result = model.result, !model.isResultBusy else {
            return
        }
        model.isResultBusy = true
        let resultID = result.id

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let payload = await Task.detached(priority: .userInitiated) {
                (result.image.pngData(), result.image.tiffData())
            }.value

            self.model.isResultBusy = false
            guard self.model.result?.id == resultID else {
                return
            }
            guard let png = payload.0 else {
                self.model.showNotice(
                    IslandNotice(kind: .error, message: CaptureError.encodeFailed.localizedDescription)
                )
                return
            }

            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            if let tiff = payload.1 {
                item.setData(tiff, forType: .tiff)
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.writeObjects([item]) else {
                self.model.showNotice(IslandNotice(kind: .error, message: "复制失败，截图仍保留，请重试。"))
                return
            }

            Logger.capture.info("Screenshot copied auto=\(isAutomatic, privacy: .public)")
            self.model.showNotice(
                IslandNotice(
                    kind: .success,
                    message: isAutomatic ? "已自动复制到剪贴板" : "已复制到剪贴板"
                )
            )
        }
    }

    private func recognizeResultText() {
        guard let result = model.result, !model.isResultBusy else {
            return
        }
        model.isResultBusy = true
        let resultID = result.id

        Task { @MainActor [weak self] in
            let outcome = await TextRecognizer.recognize(in: result.image)
            guard let self else {
                return
            }
            self.model.isResultBusy = false
            guard self.model.result?.id == resultID else {
                return
            }

            switch outcome {
            case .text(let text):
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                guard pasteboard.setString(text, forType: .string) else {
                    self.model.showNotice(
                        IslandNotice(kind: .error, message: "文字已识别，但复制失败，请重试。")
                    )
                    return
                }
                Logger.capture.info("OCR copied chars=\(text.count, privacy: .public)")
                self.model.showNotice(
                    IslandNotice(kind: .success, message: "已识别并复制 \(text.count) 个字符")
                )
            case .empty:
                self.model.showNotice(IslandNotice(kind: .info, message: "没有识别到文字"))
            case .failed:
                self.model.showNotice(IslandNotice(kind: .error, message: "文字识别失败，请重试"))
            }
        }
    }

    private func saveResult() {
        guard let result = model.result, !model.isResultBusy, suspensionCount == 0 else {
            return
        }

        let screenshotDirectory = existingDirectory(
            at: config.settings.screenshotDirectoryPath
        )
        if config.settings.screenshotSaveWithoutPrompt, let screenshotDirectory {
            let targetURL = FilenameAllocator.uniqueURL(
                in: screenshotDirectory,
                baseName: result.suggestedBaseName,
                fileExtension: "png"
            )
            model.isResultBusy = true
            Task { @MainActor in
                await self.writeResult(result, to: targetURL)
            }
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(result.suggestedBaseName).png"
        panel.message = "选择栖岛截图的保存位置"
        if let screenshotDirectory {
            panel.directoryURL = screenshotDirectory
        }

        beginSuspension()
        NSApp.activate(ignoringOtherApps: true)
        activeScene?.presenter.resignKey()
        panel.begin { [weak self] response in
            guard let self else {
                return
            }
            Task { @MainActor in
                defer {
                    self.endSuspension()
                    self.restoreKeyIfPossible()
                }
                guard response == .OK, let chosenURL = panel.url else {
                    return
                }
                let targetURL = FilenameAllocator.uniqueURL(for: chosenURL)
                await self.writeResult(result, to: targetURL)
            }
        }
    }

    private func writeResult(_ result: ScreenshotResult, to url: URL) async {
        model.isResultBusy = true
        defer {
            model.isResultBusy = false
        }

        let data = await Task.detached(priority: .userInitiated) {
            result.image.pngData()
        }.value

        guard let data else {
            model.showNotice(
                IslandNotice(
                    kind: .error,
                    message: "保存失败：\(CaptureError.encodeFailed.localizedDescription)，结果仍保留",
                    actions: [.init(title: "重试", style: .standard) { [weak self] in
                        self?.saveResult()
                    }]
                )
            )
            return
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Logger.capture.error("Screenshot write failed: \(error.localizedDescription, privacy: .public)")
            model.showNotice(
                IslandNotice(
                    kind: .error,
                    message: "保存失败，结果仍保留，可重试",
                    actions: [.init(title: "重试", style: .standard) { [weak self] in
                        self?.saveResult()
                    }]
                )
            )
            return
        }

        guard model.result?.id == result.id else {
            return
        }
        if var updated = model.result {
            updated.savedURL = url
            model.result = updated
        }
        updateFocusItems()
        Logger.capture.info("Screenshot saved")
        model.showNotice(IslandNotice(kind: .success, message: "已保存 \(url.lastPathComponent)"))
    }

    private func shareResult() {
        guard let result = model.result, !model.isResultBusy else {
            return
        }
        model.isResultBusy = true
        Task { @MainActor [weak self] in
            let data = await Task.detached(priority: .userInitiated) {
                result.image.pngData()
            }.value

            guard let self else {
                return
            }
            self.model.isResultBusy = false

            guard let data else {
                self.presentNotice(
                    IslandNotice(kind: .error, message: "分享失败：图片编码失败")
                )
                return
            }
            guard self.model.result?.id == result.id else {
                return
            }
            guard let url = ShareFiles.writePNG(
                data: data,
                baseName: result.suggestedBaseName
            ) else {
                self.presentNotice(
                    IslandNotice(kind: .error, message: "分享准备失败，请重试")
                )
                return
            }
            self.presentResultSharingPicker(for: url)
        }
    }

    private func presentResultSharingPicker(for url: URL) {
        let window = NSApp.keyWindow ?? activeScene?.presenter.panelWindow
        guard let view = window?.contentView else {
            return
        }
        let picker = NSSharingServicePicker(items: [url])
        resultSharePicker = picker
        let mouse = window?.mouseLocationOutsideOfEventStream
            ?? NSPoint(x: view.bounds.midX, y: view.bounds.midY)
        let point = view.convert(mouse, from: nil)
        picker.show(
            relativeTo: NSRect(x: point.x, y: point.y, width: 1, height: 1),
            of: view,
            preferredEdge: .minY
        )
    }

    private func revealResult() {
        guard let url = model.result?.savedURL else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        collapse(animated: true)
    }

    private func closeResult(returnToTools: Bool) {
        guard model.result != nil else {
            return
        }
        model.clearResult()
        model.isResultBusy = false
        updateFocusItems()
        model.selectedFocus = focusItems.first
        model.keyboardFocusVisible = false
        if !returnToTools {
            collapse(animated: true)
        }
    }

    // MARK: - Workspace, settings and onboarding

    private func captureFromWorkspace(_ kind: CaptureKind) {
        workspaceWindow.close()
        startCapture(kind)
    }

    func openWorkspace(section: WorkspaceSection = .overview) {
        guard !isCapturing, !isSystemHidden, !isOnboardingOpen else {
            return
        }
        isWorkspaceOpen = true
        collapseImmediatelyForExternalUI()
        workspaceWindow.show(section: section)
    }

    func openSettings(tab: SettingsTab) {
        guard !isCapturing, !isSystemHidden, !isOnboardingOpen else {
            return
        }
        isWorkspaceOpen = true
        collapseImmediatelyForExternalUI()
        workspaceWindow.show(section: .settings, settingsTab: tab)
    }

    private func workspaceDidClose() {
        guard isWorkspaceOpen else {
            return
        }
        isWorkspaceOpen = false
        configurationDidChange()
        if !model.isExpanded, !isOnboardingOpen {
            DispatchQueue.main.async {
                NSApp.deactivate()
            }
        }
    }

    func showOnboarding() {
        guard !isCapturing, !isSystemHidden, !isOnboardingOpen else {
            return
        }
        isOnboardingOpen = true
        if isWorkspaceOpen {
            workspaceWindow.close()
        }
        beginSuspension()
        collapseImmediatelyForExternalUI()
        onboardingWindow.show()
    }

    private func onboardingDidFinish() {
        guard isOnboardingOpen else {
            return
        }
        isOnboardingOpen = false
        endSuspension()
        config.completeOnboarding()
        configurationDidChange()
        guard !isSystemHidden else {
            return
        }
        showAllCollapsed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, !self.isSystemHidden, !self.isCapturing,
                  let scene = self.activeScene ?? self.sceneUnderMouse() else {
                return
            }
            self.expand(on: scene, makeKey: true)
        }
    }

    // MARK: - Suspension

    private func beginSuspension() {
        suspensionCount += 1
    }

    private func endSuspension() {
        suspensionCount = max(0, suspensionCount - 1)
    }
}
