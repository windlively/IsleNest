import SwiftUI

struct SettingsSurface: View {
    var cornerRadius: CGFloat = 16
    var tint: Color?

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            let glass: Glass = tint.map { .regular.tint($0) } ?? .regular
            Color.clear
                .glassEffect(
                    glass,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                            .font(.system(size: 21, weight: .semibold))
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }
}

struct SettingsCard<Content: View>: View {
    var title: String?
    var trailing: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .padding(.horizontal, 6)
            }

            VStack(spacing: 0) {
                content
            }
            .background {
                SettingsSurface(tint: IslandTheme.accent.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let footer {
                Text(footer)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }
}

struct SettingsRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.065))
            .frame(height: 0.5)
            .padding(.leading, 14)
    }
}

struct SettingsPickerRow<Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var control: Content

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            control
                .labelsHidden()
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 44)
    }
}

struct SettingsBackdrop: View {
    let palette: IslandPalette

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let extent = max(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [palette.backgroundTop, palette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(palette.halos) { halo in
                    RadialGradient(
                        colors: [
                            halo.color.opacity(halo.opacity(for: colorScheme) * (colorScheme == .dark ? 1.15 : 0.9)),
                            halo.color.opacity(0)
                        ],
                        center: halo.center,
                        startRadius: 0,
                        endRadius: extent * halo.radiusFraction
                    )
                    .blendMode(colorScheme == .dark ? .screen : .normal)
                }

                LinearGradient(
                    colors: [Color.white.opacity(colorScheme == .dark ? 0.035 : 0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
