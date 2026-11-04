import SwiftUI

extension View {
    func islandFocusRing(_ isSelected: Bool, cornerRadius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    IslandTheme.accent.opacity(isSelected ? 0.85 : 0),
                    lineWidth: 1.2
                )
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    func islandGlass(
        _ role: IslandGlassRole = .tile,
        cornerRadius: CGFloat,
        active: Bool = false,
        interactive: Bool = true
    ) -> some View {
        if #available(macOS 26.0, *), role.supportsLiquidGlass {
            modifier(
                IslandLiquidGlassModifier(
                    role: role,
                    cornerRadius: cornerRadius,
                    isInteractive: interactive
                )
            )
        } else {
            modifier(
                IslandGlassModifier(
                    role: role,
                    cornerRadius: cornerRadius,
                    isActive: active,
                    isInteractive: interactive
                )
            )
        }
    }
}

enum IslandGlassRole {
    case tile
    case card
    case quiet
    case control
    case prominent
    case panel
    case hero

    fileprivate var supportsLiquidGlass: Bool {
        switch self {
        case .tile, .card, .hero:
            return true
        case .quiet, .control, .prominent, .panel:
            return false
        }
    }
}

struct IslandGlassContainer<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

@available(macOS 26.0, *)
private struct IslandLiquidGlassModifier: ViewModifier {
    let role: IslandGlassRole
    let cornerRadius: CGFloat
    let isInteractive: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var glass: Glass {
        switch role {
        case .hero:
            return .regular.tint(IslandTheme.accent.opacity(0.22))
        default:
            return .regular.interactive(isInteractive)
        }
    }

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
    }
}

private struct IslandGlassModifier: ViewModifier {
    let role: IslandGlassRole
    let cornerRadius: CGFloat
    let isActive: Bool
    let isInteractive: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch role {
        case .hero:
            content
                .background {
                    shape.fill(
                        LinearGradient(
                            colors: [
                                IslandTheme.accent.opacity(0.085),
                                IslandTheme.contrast(0.05),
                                IslandTheme.contrast(0.015)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [IslandTheme.accent.opacity(0.22), IslandTheme.contrast(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                    .allowsHitTesting(false)
                }
        default:
            content
                .background { shape.fill(surfaceFill) }
                .overlay { shape.strokeBorder(surfaceStroke, lineWidth: 0.5).allowsHitTesting(false) }
        }
    }

    private var surfaceFill: Color {
        switch role {
        case .tile:
            return isActive ? IslandTheme.tileFillHover : IslandTheme.tileFill
        case .quiet:
            return IslandTheme.contrast(isActive ? 0.055 : 0)
        case .card:
            return IslandTheme.contrast(isActive ? 0.055 : 0)
        case .control:
            return IslandTheme.contrast(isActive ? 0.075 : 0.035)
        case .prominent:
            return IslandTheme.accent.opacity(isActive ? 1 : 0.92)
        case .panel:
            return IslandTheme.panelFill
        case .hero:
            return .clear
        }
    }

    private var surfaceStroke: Color {
        switch role {
        case .tile:
            return isActive ? IslandTheme.tileStrokeHover : IslandTheme.tileStroke
        case .control, .quiet, .card, .hero:
            return .clear
        case .prominent:
            return .clear
        case .panel:
            return IslandTheme.contrast(0.08)
        }
    }
}

struct HeaderIconButton: View {
    let symbol: String
    let label: String
    let focusID: IslandFocusID
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == focusID
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isHovered ? IslandTheme.textPrimary : IslandTheme.textSecondary)
                .frame(width: 30, height: 30)
                .islandGlass(.quiet, cornerRadius: 9, active: isHovered)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 9)
        .help(label)
        .accessibilityLabel(label)
    }
}

struct SectionHeader: View {
    let title: String
    let actionTitle: String
    let focusID: IslandFocusID
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == focusID
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(IslandTheme.textSecondary)
                .tracking(0.3)

            Spacer(minLength: 0)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? IslandTheme.textPrimary : IslandTheme.textTertiary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .islandGlass(.control, cornerRadius: 7, active: isHovered)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .islandFocusRing(isSelected, cornerRadius: 6)
            .accessibilityLabel("\(actionTitle)\(title)")
        }
        .frame(height: 20)
    }
}

struct IslandTileButton<Content: View>: View {
    let focusID: IslandFocusID
    let accessibilityLabel: String
    let accessibilityHint: String?
    let height: CGFloat
    var prominent = false
    var quiet = false
    var card = false
    @ObservedObject var model: IslandModel
    let action: () -> Void
    @ViewBuilder let content: Content

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == focusID
    }

    private var glassRole: IslandGlassRole {
        if prominent { return .prominent }
        if card { return .card }
        return quiet ? .quiet : .tile
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .islandGlass(glassRole, cornerRadius: 12, active: isHovered)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 12)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .help(accessibilityLabel)
    }
}

struct IslandPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ShortcutKey: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(IslandTheme.textTertiary)
            .padding(.horizontal, 5)
            .frame(height: 19)
            .background(IslandTheme.contrast(0.035), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(IslandTheme.contrast(0.06), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

struct AddTileContent: View {
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(IslandTheme.textTertiary)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(IslandTheme.contrast(0.035))
                )
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(IslandTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

struct EmptySectionButton: View {
    let symbol: String
    let title: String
    let detail: String
    let focusID: IslandFocusID
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == focusID
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(IslandTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(IslandTheme.contrast(0.035))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(IslandTheme.textPrimary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(IslandTheme.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(IslandTheme.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .islandGlass(.quiet, cornerRadius: 12, active: isHovered)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(IslandTheme.contrast(isHovered ? 0.16 : 0.09),
                                  style: StrokeStyle(lineWidth: 0.75, dash: [3, 4]))
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 12)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

struct NoticeOverlay: View {
    let notice: IslandNotice
    let dismiss: () -> Void

    private var iconName: String {
        switch notice.kind {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch notice.kind {
        case .success:
            return IslandTheme.accent
        case .info:
            return IslandTheme.textSecondary
        case .error:
            return IslandTheme.error
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)

            Text(notice.message)
                .font(.system(size: 12))
                .foregroundStyle(IslandTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(notice.message)

            Spacer(minLength: 6)

            ForEach(notice.actions.prefix(2)) { action in
                Button {
                    dismiss()
                    action.handler()
                } label: {
                    Text(action.title)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(
                            action.style == .destructive ? IslandTheme.error : IslandTheme.accent
                        )
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(
                                    (action.style == .destructive ? IslandTheme.error : IslandTheme.accent)
                                        .opacity(0.1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.title)
            }

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭提示")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .islandGlass(.panel, cornerRadius: 13, interactive: false)
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}
