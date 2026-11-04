import AppKit
import IsleNestCore
import SwiftUI

extension Color {
    static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightOpacity: Double = 1,
        darkOpacity: Double = 1
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkOpacity : lightOpacity
            )
        })
    }
}

struct IslandHalo: Identifiable {
    let id: Int
    let color: Color
    let darkOpacity: Double
    let lightOpacity: Double
    let center: UnitPoint
    let radiusFraction: CGFloat

    func opacity(for scheme: ColorScheme) -> Double {
        scheme == .dark ? darkOpacity : lightOpacity
    }
}

struct IslandPalette {
    let accent: Color
    let accentDeep: Color
    let accentInk: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let halos: [IslandHalo]
    let badgeFill: Color
    let dropFill: Color
    let panelFill: Color
}

extension IslandThemePreset {
    var displayName: String {
        switch self {
        case .moss:
            return "苔屿"
        case .dusk:
            return "暮霞"
        case .tide:
            return "潮汐"
        case .aurora:
            return "星野"
        case .ember:
            return "暖砂"
        }
    }

    var englishName: String {
        switch self {
        case .moss:
            return "MOSS"
        case .dusk:
            return "DUSK"
        case .tide:
            return "TIDE"
        case .aurora:
            return "AURORA"
        case .ember:
            return "EMBER"
        }
    }

    var themeDescription: String {
        switch self {
        case .moss:
            return "苔绿与雾青，安静清爽"
        case .dusk:
            return "珊瑚与暮紫，温暖柔和"
        case .tide:
            return "海蓝与潮青，冷静通透"
        case .aurora:
            return "星紫与极光绿，幽深梦幻"
        case .ember:
            return "琥珀与陶土，沉稳有温度"
        }
    }

    var palette: IslandPalette {
        switch self {
        case .moss:
            return IslandPalette(
                accent: .adaptive(light: 0x3F6B54, dark: 0xC1D6C8),
                accentDeep: .adaptive(light: 0x2E523E, dark: 0x9EB9A8),
                accentInk: .adaptive(light: 0xFFFFFF, dark: 0x0A2018),
                backgroundTop: .adaptive(light: 0xFAFBF8, dark: 0x000000),
                backgroundBottom: .adaptive(light: 0xE7EFE8, dark: 0x0E100F),
                halos: [
                    IslandHalo(id: 0, color: .adaptive(light: 0x6FB78E, dark: 0x86C7A2), darkOpacity: 0.30, lightOpacity: 0.17, center: UnitPoint(x: 0.02, y: -0.04), radiusFraction: 0.80),
                    IslandHalo(id: 1, color: .adaptive(light: 0x5E94AC, dark: 0x5E94AC), darkOpacity: 0.20, lightOpacity: 0.11, center: UnitPoint(x: 1.02, y: 0.22), radiusFraction: 0.66),
                    IslandHalo(id: 2, color: .adaptive(light: 0xC2A96F, dark: 0xCBB786), darkOpacity: 0.13, lightOpacity: 0.08, center: UnitPoint(x: 0.28, y: 1.08), radiusFraction: 0.68),
                    IslandHalo(id: 3, color: .adaptive(light: 0x8FD0AB, dark: 0xA9E0C0), darkOpacity: 0.10, lightOpacity: 0.06, center: UnitPoint(x: 0.62, y: 0.42), radiusFraction: 0.48),
                    IslandHalo(id: 4, color: .adaptive(light: 0xBFDCCB, dark: 0x6EBD93), darkOpacity: 0.14, lightOpacity: 0.05, center: UnitPoint(x: 0.5, y: 0.42), radiusFraction: 0.98)
                ],
                badgeFill: .adaptive(light: 0xDEEADF, dark: 0x2C3A32),
                dropFill: .adaptive(light: 0xF0F6F1, dark: 0x1A211D),
                panelFill: .adaptive(light: 0xF6FAF6, dark: 0x1D2321)
            )

        case .dusk:
            return IslandPalette(
                accent: .adaptive(light: 0xA8574C, dark: 0xF0C3B2),
                accentDeep: .adaptive(light: 0x8C423A, dark: 0xD39787),
                accentInk: .adaptive(light: 0xFFFFFF, dark: 0x2B130D),
                backgroundTop: .adaptive(light: 0xFEFAF7, dark: 0x000000),
                backgroundBottom: .adaptive(light: 0xF2E6E0, dark: 0x110C0E),
                halos: [
                    IslandHalo(id: 0, color: .adaptive(light: 0xD77878, dark: 0xE58E8E), darkOpacity: 0.31, lightOpacity: 0.17, center: UnitPoint(x: 0.98, y: -0.02), radiusFraction: 0.78),
                    IslandHalo(id: 1, color: .adaptive(light: 0xD38E57, dark: 0xE0A46F), darkOpacity: 0.21, lightOpacity: 0.12, center: UnitPoint(x: -0.02, y: 0.28), radiusFraction: 0.64),
                    IslandHalo(id: 2, color: .adaptive(light: 0x9C77A8, dark: 0x8E6A9A), darkOpacity: 0.17, lightOpacity: 0.10, center: UnitPoint(x: 0.72, y: 1.06), radiusFraction: 0.68),
                    IslandHalo(id: 3, color: .adaptive(light: 0xE8A58C, dark: 0xF2B8A0), darkOpacity: 0.10, lightOpacity: 0.06, center: UnitPoint(x: 0.38, y: 0.35), radiusFraction: 0.46),
                    IslandHalo(id: 4, color: .adaptive(light: 0xE0BCB0, dark: 0xE39A85), darkOpacity: 0.14, lightOpacity: 0.05, center: UnitPoint(x: 0.5, y: 0.40), radiusFraction: 0.98)
                ],
                badgeFill: .adaptive(light: 0xF2E1DB, dark: 0x3D2A2A),
                dropFill: .adaptive(light: 0xFBF2EE, dark: 0x231A1B),
                panelFill: .adaptive(light: 0xFBF6F3, dark: 0x261E20)
            )

        case .tide:
            return IslandPalette(
                accent: .adaptive(light: 0x2E6A7D, dark: 0xBEDAE7),
                accentDeep: .adaptive(light: 0x225566, dark: 0x8DB6C9),
                accentInk: .adaptive(light: 0xFFFFFF, dark: 0x08202B),
                backgroundTop: .adaptive(light: 0xF8FCFD, dark: 0x000000),
                backgroundBottom: .adaptive(light: 0xE0EDF2, dark: 0x080D11),
                halos: [
                    IslandHalo(id: 0, color: .adaptive(light: 0x4FA3B9, dark: 0x5FB3CA), darkOpacity: 0.30, lightOpacity: 0.17, center: UnitPoint(x: -0.02, y: 0.04), radiusFraction: 0.80),
                    IslandHalo(id: 1, color: .adaptive(light: 0x5D7BC6, dark: 0x5D7BC6), darkOpacity: 0.21, lightOpacity: 0.12, center: UnitPoint(x: 1.02, y: 0.36), radiusFraction: 0.66),
                    IslandHalo(id: 2, color: .adaptive(light: 0x6FBFA5, dark: 0x7CCCB2), darkOpacity: 0.14, lightOpacity: 0.09, center: UnitPoint(x: 0.55, y: 1.08), radiusFraction: 0.62),
                    IslandHalo(id: 3, color: .adaptive(light: 0x8CC7D8, dark: 0xA5D8E8), darkOpacity: 0.10, lightOpacity: 0.06, center: UnitPoint(x: 0.45, y: 0.30), radiusFraction: 0.46),
                    IslandHalo(id: 4, color: .adaptive(light: 0xBCDCE6, dark: 0x74C2D6), darkOpacity: 0.14, lightOpacity: 0.05, center: UnitPoint(x: 0.5, y: 0.42), radiusFraction: 0.98)
                ],
                badgeFill: .adaptive(light: 0xDDEBF1, dark: 0x24343D),
                dropFill: .adaptive(light: 0xEFF8FA, dark: 0x172024),
                panelFill: .adaptive(light: 0xF5FAFB, dark: 0x1A2229)
            )

        case .aurora:
            return IslandPalette(
                accent: .adaptive(light: 0x6A55A3, dark: 0xCDBDEE),
                accentDeep: .adaptive(light: 0x564388, dark: 0xA68FD3),
                accentInk: .adaptive(light: 0xFFFFFF, dark: 0x170F27),
                backgroundTop: .adaptive(light: 0xFBF9FE, dark: 0x000000),
                backgroundBottom: .adaptive(light: 0xEBE5F4, dark: 0x0B0911),
                halos: [
                    IslandHalo(id: 0, color: .adaptive(light: 0x8769CA, dark: 0x9778D8), darkOpacity: 0.31, lightOpacity: 0.17, center: UnitPoint(x: -0.02, y: 0.00), radiusFraction: 0.80),
                    IslandHalo(id: 1, color: .adaptive(light: 0x5A7CCB, dark: 0x5A7CCB), darkOpacity: 0.21, lightOpacity: 0.12, center: UnitPoint(x: 1.00, y: 0.40), radiusFraction: 0.66),
                    IslandHalo(id: 2, color: .adaptive(light: 0xC774A2, dark: 0xD584B2), darkOpacity: 0.15, lightOpacity: 0.09, center: UnitPoint(x: 0.48, y: 1.08), radiusFraction: 0.64),
                    IslandHalo(id: 3, color: .adaptive(light: 0x67C8AF, dark: 0x7CE0C2), darkOpacity: 0.10, lightOpacity: 0.06, center: UnitPoint(x: 0.90, y: 0.92), radiusFraction: 0.44),
                    IslandHalo(id: 4, color: .adaptive(light: 0xC9BCE8, dark: 0x8F7BD8), darkOpacity: 0.14, lightOpacity: 0.05, center: UnitPoint(x: 0.5, y: 0.40), radiusFraction: 0.98)
                ],
                badgeFill: .adaptive(light: 0xE8E1F3, dark: 0x332B42),
                dropFill: .adaptive(light: 0xF4F1FA, dark: 0x1E1926),
                panelFill: .adaptive(light: 0xF9F7FC, dark: 0x211C29)
            )

        case .ember:
            return IslandPalette(
                accent: .adaptive(light: 0x96643A, dark: 0xEAC9A2),
                accentDeep: .adaptive(light: 0x7C502B, dark: 0xC99F72),
                accentInk: .adaptive(light: 0xFFFFFF, dark: 0x261708),
                backgroundTop: .adaptive(light: 0xFDFAF5, dark: 0x000000),
                backgroundBottom: .adaptive(light: 0xF1E7D9, dark: 0x100C09),
                halos: [
                    IslandHalo(id: 0, color: .adaptive(light: 0xC98A40, dark: 0xD89F58), darkOpacity: 0.30, lightOpacity: 0.17, center: UnitPoint(x: -0.02, y: 0.02), radiusFraction: 0.80),
                    IslandHalo(id: 1, color: .adaptive(light: 0xC0644E, dark: 0xC66F56), darkOpacity: 0.20, lightOpacity: 0.12, center: UnitPoint(x: 1.02, y: 0.30), radiusFraction: 0.64),
                    IslandHalo(id: 2, color: .adaptive(light: 0x9C9460, dark: 0xA79E68), darkOpacity: 0.13, lightOpacity: 0.08, center: UnitPoint(x: 0.30, y: 1.08), radiusFraction: 0.62),
                    IslandHalo(id: 3, color: .adaptive(light: 0xDDBD8B, dark: 0xF0D2A2), darkOpacity: 0.10, lightOpacity: 0.06, center: UnitPoint(x: 0.55, y: 0.30), radiusFraction: 0.46),
                    IslandHalo(id: 4, color: .adaptive(light: 0xE5CDA8, dark: 0xD9A868), darkOpacity: 0.14, lightOpacity: 0.05, center: UnitPoint(x: 0.5, y: 0.42), radiusFraction: 0.98)
                ],
                badgeFill: .adaptive(light: 0xF1E5D4, dark: 0x3C3024),
                dropFill: .adaptive(light: 0xFAF4EB, dark: 0x221B15),
                panelFill: .adaptive(light: 0xFBF7F1, dark: 0x251F19)
            )
        }
    }
}

struct IslandDiffuseBackground: View {
    let palette: IslandPalette

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let extent = max(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [palette.backgroundTop, palette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(palette.halos) { halo in
                    RadialGradient(
                        colors: [
                            halo.color.opacity(halo.opacity(for: colorScheme)),
                            halo.color.opacity(0)
                        ],
                        center: halo.center,
                        startRadius: 0,
                        endRadius: extent * halo.radiusFraction
                    )
                    .blendMode(colorScheme == .dark ? .screen : .normal)
                }

                // Keeps the notch band pure black in dark themes and clean warm-white in light themes.
                LinearGradient(
                    stops: [
                        .init(color: palette.backgroundTop, location: 0),
                        .init(color: palette.backgroundTop, location: 0.06),
                        .init(color: palette.backgroundTop.opacity(0), location: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.03), Color.white.opacity(0), Color.black.opacity(0.05)]
                        : [Color.white.opacity(0.35), Color.white.opacity(0), Color.black.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}
