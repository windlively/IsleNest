import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class IslandScene: ObservableObject, Identifiable {
    let id = UUID()
    private(set) var screen: NSScreen
    let presenter = IslandPresenter()

    @Published private(set) var isActive = false
    @Published private(set) var isPeeking = false
    @Published private(set) var style: ResolvedIslandStyle
    @Published private(set) var collapsedSize: CGSize
    @Published private(set) var peekSize: CGSize
    @Published private(set) var expandedSize: CGSize
    @Published private(set) var contentTopInset: CGFloat
    @Published private(set) var notchWidth: CGFloat
    @Published private(set) var windowSize: CGSize

    private(set) var collapsedLayout: IslandLayout
    private(set) var peekLayout: IslandLayout
    private(set) var expandedLayout: IslandLayout

    var displayID: CGDirectDisplayID? {
        screen.displayID
    }

    init(
        screen: NSScreen,
        collapsed: IslandLayout,
        peek: IslandLayout,
        expanded: IslandLayout
    ) {
        self.screen = screen
        self.style = expanded.style
        self.collapsedSize = collapsed.islandRect.size
        self.peekSize = peek.islandRect.size
        self.expandedSize = expanded.islandRect.size
        self.contentTopInset = expanded.contentTopInset
        self.notchWidth = expanded.notchWidth
        self.windowSize = collapsed.windowRect.size
        self.collapsedLayout = collapsed
        self.peekLayout = peek
        self.expandedLayout = expanded
    }

    func update(
        screen: NSScreen,
        collapsed: IslandLayout,
        peek: IslandLayout,
        expanded: IslandLayout
    ) {
        self.screen = screen
        self.collapsedLayout = collapsed
        self.peekLayout = peek
        self.expandedLayout = expanded
        style = expanded.style
        collapsedSize = collapsed.islandRect.size
        peekSize = peek.islandRect.size
        expandedSize = expanded.islandRect.size
        contentTopInset = expanded.contentTopInset
        notchWidth = expanded.notchWidth
    }

    func setActive(_ active: Bool) {
        guard isActive != active else {
            return
        }
        isActive = active
    }

    func setPeeking(_ peeking: Bool) {
        guard isPeeking != peeking else {
            return
        }
        isPeeking = peeking
    }

    func setWindowSize(_ size: CGSize) {
        guard windowSize != size else {
            return
        }
        windowSize = size
    }
}
