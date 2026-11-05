import IsleNestCore
import SwiftUI

struct ThemePickerView: View {
    @Binding var selection: IslandThemePreset

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(IslandThemePreset.allCases, id: \.self) { preset in
                ThemeSwatch(preset: preset, isSelected: selection == preset) {
                    selection = preset
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ThemeSwatch: View {
    let preset: IslandThemePreset
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        let palette = preset.palette

        Button(action: action) {
            VStack(spacing: 6) {
                preview(palette: palette)
                HStack(spacing: 4) {
                    Text(preset.displayName)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    Text(preset.englishName)
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.tertiary)
                }
                .lineLimit(1)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.primary.opacity(0.045)
                            : (isHovered ? Color.primary.opacity(0.03) : Color.clear)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .help("\(preset.displayName) · \(preset.themeDescription)")
        .accessibilityLabel("\(preset.displayName)主题")
        .accessibilityHint(preset.themeDescription)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func preview(palette: IslandPalette) -> some View {
        ZStack(alignment: .top) {
            IslandDiffuseBackground(palette: palette)

            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 5,
                bottomTrailingRadius: 5,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black)
            .frame(width: 54, height: 11)
            .overlay {
                HStack(spacing: 17) {
                    Circle().fill(palette.accent).frame(width: 2, height: 2)
                    Circle().fill(palette.accent).frame(width: 2, height: 2)
                }
            }

            VStack {
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(IslandTheme.contrast(0.10))
                            .frame(height: 5)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? palette.accent.opacity(0.9)
                        : IslandTheme.contrast(isHovered ? 0.22 : 0.08),
                    lineWidth: isSelected ? 1.4 : 0.75
                )
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(palette.accentInk)
                    .frame(width: 14, height: 14)
                    .background(palette.accent, in: Circle())
                    .padding(4)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isSelected)
    }
}
