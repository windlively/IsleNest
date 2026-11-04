import AppKit
import IsleNestCore
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension IslandAppearanceMode {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

enum IslandTheme {
    static let expandedSize = CGSize(width: 464, height: 480)
    static let collapsedSize = CGSize(width: 136, height: 36)
    // No-notch screens use a narrow floating capsule so they cover far fewer menu bar items.
    static let menuBarIdleWidth: CGFloat = 160
    // Notch bars use the measured notch width as their lower bound and this range's upper bound.
    static let menuBarWidthRange: ClosedRange<CGFloat> = 120...320
    static let menuBarPeekExtraWidth: CGFloat = 116
    static let menuBarPillVerticalInset: CGFloat = 2
    static let menuBarPillMinHeight: CGFloat = 24
    static let notchContentTopInset: CGFloat = 16
    static let notchIdleSideExtension: CGFloat = 24
    // Keeps the idle entry dots clear of both the notch cutout and the bar's rounded corners.
    static let notchMinimumSideExtension: CGFloat = 16
    static let notchTimerExtraWidth: CGFloat = 32
    static let notchPeekSideExtension: CGFloat = 78
    static let notchBarCornerRadius: CGFloat = 12
    static let collapseSettleDelay: TimeInterval = 0.42
    static let shadowInset: CGFloat = 16
    static let floatingTopGap: CGFloat = 8
    static let screenMargin: CGFloat = 12

    static let expandedCornerRadius: CGFloat = 26
    static let collapsedFloatingCornerRadius: CGFloat = 18
    static let collapsedNotchCornerRadius: CGFloat = 16

    private(set) static var preset: IslandThemePreset = .moss
    private(set) static var palette: IslandPalette = IslandThemePreset.moss.palette

    static func apply(_ preset: IslandThemePreset) {
        guard preset != self.preset else {
            return
        }
        self.preset = preset
        palette = preset.palette
    }

    static var accent: Color { palette.accent }
    static var accentDeep: Color { palette.accentDeep }
    static var accentInk: Color { palette.accentInk }
    static var backgroundTop: Color { palette.backgroundTop }
    static var backgroundBottom: Color { palette.backgroundBottom }
    static var badgeFill: Color { palette.badgeFill }
    static var dropFill: Color { palette.dropFill }
    static var panelFill: Color { palette.panelFill }
    static let surfaceBase = Color.adaptive(light: 0xF7F6F2, dark: 0x000000)
    static let textPrimary = Color.adaptive(light: 0x1D211F, dark: 0xF0F1EF)
    static let textSecondary = Color.adaptive(light: 0x5B615E, dark: 0xB9BDBD)
    static let textTertiary = Color.adaptive(light: 0x7C827F, dark: 0x919799)
    static let glassTint = Color.adaptive(light: 0xF4F2ED, dark: 0x0A0D0F, lightOpacity: 0.72, darkOpacity: 0.46)
    static let glassBaseTop = Color.adaptive(light: 0xFBFAF7, dark: 0x0B0E10, lightOpacity: 0.88, darkOpacity: 0.82)
    static let glassBaseBottom = Color.adaptive(light: 0xEDEAE4, dark: 0x050708, lightOpacity: 0.94, darkOpacity: 0.92)
    static let tileFill = contrast(0.025)
    static let tileFillHover = contrast(0.065)
    static let tileStroke = contrast(0.055)
    static let tileStrokeHover = contrast(0.11)
    static let divider = contrast(0.07)
    static let error = Color.adaptive(light: 0xB4453A, dark: 0xE4897F)
    static let warning = Color.adaptive(light: 0x946A1F, dark: 0xE3B778)

    static let glassTileBase = Color.adaptive(light: 0xF3F0EA, dark: 0x0E1215, lightOpacity: 0.55, darkOpacity: 0.34)
    static let glassTileBaseActive = Color.adaptive(light: 0xEAE6DF, dark: 0x182025, lightOpacity: 0.68, darkOpacity: 0.46)
    static let glassTileTint = Color.adaptive(light: 0xEFEBE4, dark: 0x131A1E, lightOpacity: 0.44, darkOpacity: 0.30)
    static let glassControlTint = Color.adaptive(light: 0xE9E5DE, dark: 0x101518, lightOpacity: 0.32, darkOpacity: 0.18)
    static let glassPanelBase = Color.adaptive(light: 0xF7F5F0, dark: 0x0A0D10, lightOpacity: 0.78, darkOpacity: 0.60)
    static let glassPanelTint = Color.adaptive(light: 0xEFEBE4, dark: 0x080A0C, lightOpacity: 0.46, darkOpacity: 0.34)

    /// White hairlines in dark themes become dark hairlines in light themes.
    static func contrast(_ opacity: Double, lightScale: Double = 1.15) -> Color {
        Color.adaptive(
            light: 0x000000,
            dark: 0xFFFFFF,
            lightOpacity: min(0.7, opacity * lightScale),
            darkOpacity: opacity
        )
    }

    static func morphAnimation(reduceMotion: Bool) -> Animation? {
        guard !reduceMotion else {
            return nil
        }
        return .spring(response: 0.3, dampingFraction: 0.88)
    }

    static func islandShape(style: ResolvedIslandStyle, expanded: Bool) -> AnyShape {
        switch style {
        case .notch:
            return AnyShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: notchBarCornerRadius,
                    bottomTrailingRadius: notchBarCornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
        case .menuBar:
            return AnyShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? expandedCornerRadius : collapsedNotchCornerRadius,
                    bottomTrailingRadius: expanded ? expandedCornerRadius : collapsedNotchCornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
        case .floating:
            return AnyShape(
                RoundedRectangle(
                    cornerRadius: expanded ? expandedCornerRadius : collapsedFloatingCornerRadius,
                    style: .continuous
                )
            )
        }
    }

    @ViewBuilder
    static func brandMark(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.15), accent.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .strokeBorder(accent.opacity(0.18), lineWidth: 0.5)
                }
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(accent)
                .rotationEffect(.degrees(-18))
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct IslandBarShape: Shape {
    var barWidth: CGFloat
    var bodyHeight: CGFloat
    var topInset: CGFloat = 0
    var topRadius: CGFloat = 0
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<
        CGFloat,
        AnimatablePair<
            CGFloat,
            AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>
        >
    > {
        get {
            AnimatablePair(
                barWidth,
                AnimatablePair(
                    bodyHeight,
                    AnimatablePair(
                        topInset,
                        AnimatablePair(topRadius, bottomRadius)
                    )
                )
            )
        }
        set {
            barWidth = newValue.first
            bodyHeight = newValue.second.first
            topInset = newValue.second.second.first
            topRadius = newValue.second.second.second.first
            bottomRadius = newValue.second.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let inset = max(0, min(topInset, rect.height))
        let width = max(0, min(barWidth, rect.width))
        let height = max(0, min(bodyHeight, rect.height - inset))
        let left = rect.midX - width / 2
        let right = left + width
        let top = rect.minY + inset
        let bottom = top + height
        let topR = max(0, min(topRadius, width / 2, height / 2))
        let bottomR = max(0, min(bottomRadius, width / 2, height / 2))

        var path = Path()
        path.move(to: CGPoint(x: left + topR, y: top))
        path.addLine(to: CGPoint(x: right - topR, y: top))
        if topR > 0 {
            path.addQuadCurve(
                to: CGPoint(x: right, y: top + topR),
                control: CGPoint(x: right, y: top)
            )
        }
        path.addLine(to: CGPoint(x: right, y: bottom - bottomR))
        if bottomR > 0 {
            path.addQuadCurve(
                to: CGPoint(x: right - bottomR, y: bottom),
                control: CGPoint(x: right, y: bottom)
            )
        }
        path.addLine(to: CGPoint(x: left + bottomR, y: bottom))
        if bottomR > 0 {
            path.addQuadCurve(
                to: CGPoint(x: left, y: bottom - bottomR),
                control: CGPoint(x: left, y: bottom)
            )
        }
        path.addLine(to: CGPoint(x: left, y: top + topR))
        if topR > 0 {
            path.addQuadCurve(
                to: CGPoint(x: left + topR, y: top),
                control: CGPoint(x: left, y: top)
            )
        }
        path.closeSubpath()
        return path
    }
}

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var cache: [String: NSImage] = [:]

    func icon(for item: LaunchItem) -> NSImage? {
        guard item.kind == .application, let url = item.applicationURL else {
            return nil
        }
        let key = url.path
        if let cached = cache[key] {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: key)
        icon.size = NSSize(width: 64, height: 64)
        cache[key] = icon
        return icon
    }

    func folderIcon() -> NSImage? {
        NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "文件夹")
    }
}
