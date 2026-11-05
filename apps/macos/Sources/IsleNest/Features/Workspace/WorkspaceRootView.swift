import AppKit
import IsleNestCore
import SwiftUI

struct WorkspaceRootView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var navigation: WorkspaceNavigation
    let services: WorkspaceServices
    let actions: WorkspaceActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toast: WorkspaceToast?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            WorkspaceWindowBackdrop(style: config.settings.workspaceBackdrop)
                .id(config.settings.workspaceBackdrop)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            SettingsBackdrop(palette: config.settings.theme.palette)
                .opacity(0.26)

            HStack(spacing: 12) {
                WorkspaceSidebar(config: config, navigation: navigation)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background {
                        WorkspaceGlassSurface(cornerRadius: 20, tint: IslandTheme.accent.opacity(0.03))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.top, 28)
            .padding(.bottom, 12)

            if let toast {
                VStack {
                    Spacer()
                    WorkspaceToastOverlay(toast: toast)
                        .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
                .zIndex(2)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .tint(IslandTheme.accentDeep)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: toast?.id)
        .onDisappear {
            toastTask?.cancel()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.section {
        case .overview:
            WorkspaceOverviewView(
                config: config,
                services: services,
                actions: actions,
                openSection: { navigation.section = $0 },
                showToast: showToast
            )
        case .files:
            WorkspaceFilesView(
                services: services,
                actions: actions,
                navigation: navigation,
                showToast: showToast
            )
        case .system:
            WorkspaceSystemView(services: services, openSection: { navigation.section = $0 })
        case .tools:
            WorkspaceToolsView(
                config: config,
                services: services,
                actions: actions,
                openSection: { navigation.section = $0 },
                openSettings: { tab in
                    navigation.settingsTab = tab
                    navigation.section = .settings
                }
            )
        case .settings:
            WorkspaceSettingsView(config: config, navigation: navigation)
        }
    }

    private func showToast(_ kind: WorkspaceToast.Kind, _ text: String) {
        toastTask?.cancel()
        let next = WorkspaceToast(kind: kind, text: text)
        toast = next
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled, toast?.id == next.id else {
                return
            }
            toast = nil
        }
    }
}

private struct WorkspaceWindowBackdrop: NSViewRepresentable {
    let style: WorkspaceBackdropStyle

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassThroughVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        view.material = style.material
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        guard nsView.material != style.material else {
            return
        }
        nsView.material = style.material
        nsView.needsDisplay = true
    }
}

private final class PassThroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct WorkspaceGlassSurface: View {
    var cornerRadius: CGFloat = 20
    var tint: Color?

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    Glass.clear.tint(tint),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

private struct WorkspaceSidebar: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var navigation: WorkspaceNavigation

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private let sections: [WorkspaceSection] = [.overview, .files, .system, .tools]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            brand

            VStack(alignment: .leading, spacing: 3) {
                Text("工作区")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 10)
                    .padding(.bottom, 1)

                ForEach(sections) { section in
                    WorkspaceNavItem(section: section, isSelected: navigation.section == section) {
                        navigation.section = section
                    }
                }
            }

            Spacer(minLength: 0)

            WorkspaceNavItem(section: .settings, isSelected: navigation.section == .settings) {
                navigation.section = .settings
            }

            Text("版本 \(version) · 本地运行")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .padding(.leading, 10)
                .padding(.bottom, 2)
        }
        .padding(12)
        .frame(width: 206)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            WorkspaceGlassSurface(cornerRadius: 20, tint: IslandTheme.accent.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
    }

    private var brand: some View {
        HStack(spacing: 9) {
            IslandTheme.brandMark(size: 31)

            VStack(alignment: .leading, spacing: 1) {
                Text("栖岛工作台")
                    .font(.system(size: 14.5, weight: .semibold))
                    .tracking(0.3)
                Text("ISLENEST DESK")
                    .font(.system(size: 7, weight: .semibold))
                    .tracking(1.7)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 6)
        .padding(.top, 4)
    }
}

private struct WorkspaceNavItem: View {
    let section: WorkspaceSection
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? IslandTheme.accent : .secondary)
                    .frame(width: 23, height: 23)
                    .background(
                        isSelected
                            ? IslandTheme.accent.opacity(0.14)
                            : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )

                Text(section.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(
                isSelected
                    ? IslandTheme.accent.opacity(0.10)
                    : (isHovered ? Color.primary.opacity(0.045) : Color.clear),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(IslandTheme.accent.opacity(0.22), lineWidth: 0.75)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
