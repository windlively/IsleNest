import AppKit
import SwiftUI

struct WorkspacePageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(IslandTheme.accent)
                .frame(width: 38, height: 38)
                .background(
                    IslandTheme.accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(IslandTheme.accent.opacity(0.2), lineWidth: 0.6)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
            trailing
        }
    }
}

struct WorkspaceCard<Content: View>: View {
    var title: String?
    var trailing: String?
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || trailing != nil {
                HStack(spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.system(size: 11.5, weight: .semibold))
                            .tracking(0.2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 2)
            }

            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    SettingsSurface(tint: IslandTheme.accent.opacity(0.045))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct WorkspaceMetricCard: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .medium))
                Text(title)
                Spacer(minLength: 0)
                Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(IslandTheme.accent)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)

            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(IslandTheme.accent.opacity(0.78))
                        .frame(width: max(4, proxy.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 4)

            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            SettingsSurface(tint: IslandTheme.accent.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct WorkspaceActionTile: View {
    let symbol: String
    let title: String
    var detail: String?
    var accent = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accent ? IslandTheme.accent : .secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        IslandTheme.accent.opacity(accent ? 0.14 : 0.06),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                Color.primary.opacity(isHovered ? 0.065 : 0.035),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isHovered ? IslandTheme.accent.opacity(0.25) : Color.primary.opacity(0.06),
                        lineWidth: 0.75
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct WorkspaceSegmentedTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    let symbol: (Item) -> String?
    @Binding var selection: Item

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items) { item in
                let isSelected = item == selection
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                        selection = item
                    }
                } label: {
                    HStack(spacing: 5) {
                        if let symbol = symbol(item) {
                            Image(systemName: symbol)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        Text(title(item))
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundStyle(isSelected ? IslandTheme.accent : Color.secondary)
                    .padding(.horizontal, 11)
                    .frame(height: 27)
                    .background(
                        isSelected ? IslandTheme.accent.opacity(0.13) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(IslandTheme.accent.opacity(0.20), lineWidth: 0.75)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.75)
        }
    }
}

struct WorkspaceEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(IslandTheme.accent)
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 360)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct WorkspaceToastOverlay: View {
    let toast: WorkspaceToast

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(toast.text)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(2)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 34)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var symbol: String {
        switch toast.kind {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch toast.kind {
        case .success:
            return .green
        case .info:
            return IslandTheme.accent
        case .error:
            return IslandTheme.error
        }
    }
}
