import AppKit
import ColorSync
import CoreGraphics
import IsleNestCore

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value
    }

    var isBuiltIn: Bool {
        guard let displayID else {
            return false
        }
        return CGDisplayIsBuiltin(displayID) != 0
    }

    var displayName: String {
        let name = localizedName
        return isBuiltIn ? "\(name)（内建）" : name
    }

    // UUID survives reconnects and reboots, unlike CGDirectDisplayID.
    var configurationKey: String {
        if let displayID,
           let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        if let displayID {
            return "display-\(displayID)"
        }
        return "name-\(localizedName)"
    }
}

struct NotchMetrics {
    let hasNotch: Bool
    let topInset: CGFloat
    let notchWidth: CGFloat
}

enum ResolvedIslandStyle: Equatable, Sendable {
    case notch
    case menuBar
    case floating
}

struct IslandLayout {
    let screenFrame: NSRect
    let islandRect: NSRect
    let style: ResolvedIslandStyle
    let collapsedSize: CGSize
    let peekSize: CGSize
    let contentTopInset: CGFloat
    let notchWidth: CGFloat
    let windowRectOverride: NSRect?

    var windowInsets: NSEdgeInsets {
        if style == .floating {
            return NSEdgeInsets(
                top: IslandTheme.shadowInset,
                left: IslandTheme.shadowInset,
                bottom: IslandTheme.shadowInset,
                right: IslandTheme.shadowInset
            )
        }
        return NSEdgeInsets(
            top: 0,
            left: IslandTheme.shadowInset,
            bottom: IslandTheme.shadowInset,
            right: IslandTheme.shadowInset
        )
    }

    var windowRect: NSRect {
        if let windowRectOverride {
            return windowRectOverride
        }
        let insets = windowInsets
        return NSRect(
            x: islandRect.midX - (islandRect.width + insets.left + insets.right) / 2,
            y: islandRect.minY - insets.bottom,
            width: islandRect.width + insets.left + insets.right,
            height: islandRect.height + insets.top + insets.bottom
        )
    }
}

@MainActor
final class DisplayCoordinator {
    private let config: ConfigStore

    init(config: ConfigStore) {
        self.config = config
    }

    var screens: [NSScreen] {
        NSScreen.screens
    }

    func screen(containing point: NSPoint) -> NSScreen? {
        screens.first { $0.frame.contains(point) }
    }

    static func notchMetrics(for screen: NSScreen) -> NotchMetrics {
        let inset = screen.safeAreaInsets.top
        guard inset > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            return NotchMetrics(hasNotch: false, topInset: inset, notchWidth: 0)
        }

        let width = screen.frame.width - left.width - right.width
        return NotchMetrics(
            hasNotch: width > 80 && inset >= 20,
            topInset: inset,
            notchWidth: max(0, width)
        )
    }

    func isFullscreenActive(on screen: NSScreen) -> Bool {
        guard let displayID = screen.displayID,
              let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontPID != ProcessInfo.processInfo.processIdentifier,
              let windows = CGWindowListCopyWindowInfo(
                  [.optionOnScreenOnly, .excludeDesktopElements],
                  kCGNullWindowID
              ) as? [[String: Any]] else {
            return false
        }

        let displayBounds = CGDisplayBounds(displayID)
        return windows.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == frontPID,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: NSNumber],
                  let x = bounds["X"]?.doubleValue,
                  let y = bounds["Y"]?.doubleValue,
                  let width = bounds["Width"]?.doubleValue,
                  let height = bounds["Height"]?.doubleValue else {
                return false
            }
            return abs(x - displayBounds.minX) <= 2
                && abs(y - displayBounds.minY) <= 2
                && abs(width - displayBounds.width) <= 2
                && abs(height - displayBounds.height) <= 2
        }
    }

    func resolvedStyle(for screen: NSScreen) -> ResolvedIslandStyle {
        let metrics = Self.notchMetrics(for: screen)
        switch config.settings.style {
        case .notch, .automatic:
            return metrics.hasNotch ? .notch : .menuBar
        case .floating:
            return .floating
        }
    }

    private func configuredIdleWidth(
        for screen: NSScreen,
        default defaultWidth: CGFloat,
        minimum: CGFloat
    ) -> CGFloat {
        let configured = config.settings.displayIslandWidths[screen.configurationKey]
            .map { CGFloat($0) } ?? defaultWidth
        let upper = max(IslandTheme.menuBarWidthRange.upperBound, minimum)
        return min(max(configured, minimum), upper)
    }

    func layout(
        expanded: Bool,
        peeking: Bool = false,
        showsTimer: Bool = false,
        on screen: NSScreen
    ) -> IslandLayout {
        let style = resolvedStyle(for: screen)
        let metrics = Self.notchMetrics(for: screen)
        let topInset = max(metrics.topInset, 24)

        let notchWidth: CGFloat
        let collapsed: CGSize
        let peek: CGSize
        let contentTopInset: CGFloat
        let size: CGSize
        let topY: CGFloat
        var usesExpandedWindow = false

        switch style {
        case .notch, .menuBar:
            let barHeight = style == .notch
                ? topInset
                : max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
            let idleWidth: CGFloat
            let peekWidth: CGFloat
            if style == .notch {
                notchWidth = max(metrics.notchWidth, 120)
                let baseIdle = configuredIdleWidth(
                    for: screen,
                    default: notchWidth + IslandTheme.notchIdleSideExtension * 2,
                    minimum: notchWidth + IslandTheme.notchMinimumSideExtension * 2
                )
                // A running countdown needs a little more room in each ear.
                let timerExtra = showsTimer ? IslandTheme.notchTimerExtraWidth : 0
                idleWidth = min(
                    max(baseIdle + timerExtra, notchWidth + IslandTheme.notchMinimumSideExtension * 2),
                    IslandTheme.menuBarWidthRange.upperBound
                )
                peekWidth = notchWidth + IslandTheme.notchPeekSideExtension * 2
            } else {
                notchWidth = 0
                idleWidth = configuredIdleWidth(
                    for: screen,
                    default: IslandTheme.menuBarIdleWidth,
                    minimum: IslandTheme.menuBarWidthRange.lowerBound
                )
                peekWidth = min(
                    idleWidth + IslandTheme.menuBarPeekExtraWidth,
                    IslandTheme.expandedSize.width
                )
            }
            collapsed = CGSize(width: idleWidth, height: barHeight)
            peek = CGSize(width: peekWidth, height: barHeight)
            contentTopInset = expanded ? IslandTheme.notchContentTopInset : 0
            if expanded {
                size = CGSize(
                    width: IslandTheme.expandedSize.width,
                    height: contentTopInset + IslandTheme.expandedSize.height
                )
            } else {
                size = peeking ? peek : collapsed
            }
            // A fixed window envelope keeps collapse, peek and expand to shape-only
            // animations; resizing the panel re-anchors the hosted SwiftUI content.
            usesExpandedWindow = true
            topY = screen.frame.maxY

        case .floating:
            notchWidth = 0
            collapsed = IslandTheme.collapsedSize
            peek = collapsed
            contentTopInset = 0
            size = expanded ? IslandTheme.expandedSize : collapsed
            topY = screen.visibleFrame.maxY - IslandTheme.floatingTopGap
        }

        let centerX: CGFloat
        if style == .floating {
            switch config.settings.floatingAnchor {
            case .left:
                centerX = screen.frame.minX + IslandTheme.screenMargin + size.width / 2
            case .center:
                centerX = screen.frame.midX
            case .right:
                centerX = screen.frame.maxX - IslandTheme.screenMargin - size.width / 2
            }
        } else {
            centerX = screen.frame.midX
        }

        var x = centerX - size.width / 2
        let minX = screen.frame.minX + IslandTheme.screenMargin
        let maxX = screen.frame.maxX - IslandTheme.screenMargin - size.width
        x = min(max(x, minX), max(x, maxX))

        let islandRect = NSRect(
            x: x,
            y: topY - size.height,
            width: size.width,
            height: size.height
        )

        var windowRectOverride: NSRect?
        if usesExpandedWindow {
            let windowWidth = IslandTheme.expandedSize.width + IslandTheme.shadowInset * 2
            let windowHeight = IslandTheme.expandedSize.height
                + IslandTheme.notchContentTopInset
                + IslandTheme.shadowInset
            let windowX = min(
                max(centerX - windowWidth / 2, screen.frame.minX + IslandTheme.screenMargin),
                screen.frame.maxX - IslandTheme.screenMargin - windowWidth
            )
            windowRectOverride = NSRect(
                x: windowX,
                y: screen.frame.maxY - windowHeight,
                width: windowWidth,
                height: windowHeight
            )
        }

        return IslandLayout(
            screenFrame: screen.frame,
            islandRect: islandRect,
            style: style,
            collapsedSize: collapsed,
            peekSize: peek,
            contentTopInset: contentTopInset,
            notchWidth: notchWidth,
            windowRectOverride: windowRectOverride
        )
    }
}
