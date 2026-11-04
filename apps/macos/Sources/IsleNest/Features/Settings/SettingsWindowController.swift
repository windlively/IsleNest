import Combine
import IsleNestCore
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case folders
    case launch
    case capture
    case about

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .folders:
            return "文件夹"
        case .launch:
            return "快捷启动"
        case .capture:
            return "截屏"
        case .about:
            return "关于"
        }
    }

    var symbol: String {
        switch self {
        case .general:
            return "gearshape"
        case .folders:
            return "folder"
        case .launch:
            return "square.grid.2x2"
        case .capture:
            return "camera.viewfinder"
        case .about:
            return "info.circle"
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .general
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let config: ConfigStore
    private let navigation = SettingsNavigation()
    private let onClose: () -> Void
    private var window: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    init(config: ConfigStore, onClose: @escaping () -> Void) {
        self.config = config
        self.onClose = onClose
        super.init()

        config.$settings
            .map(\.appearance)
            .removeDuplicates()
            .sink { [weak self] appearance in
                self?.window?.appearance = appearance.nsAppearance
            }
            .store(in: &cancellables)
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func show(tab: SettingsTab) {
        navigation.tab = tab

        if window == nil {
            let view = SettingsView(config: config, navigation: navigation)
            let hosting = NSHostingController(rootView: view)
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.title = "栖岛设置"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.appearance = config.settings.appearance.nsAppearance
            window.setContentSize(NSSize(width: 840, height: 640))
            window.minSize = NSSize(width: 780, height: 560)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }

        guard let window else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

struct SettingsView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var navigation: SettingsNavigation

    @StateObject private var loginModel = LoginItemModel()
    @StateObject private var permissionModel = ScreenPermissionModel()
    @State private var message: String?

    var body: some View {
        ZStack {
            SettingsBackdrop(palette: config.settings.theme.palette)

            HStack(spacing: 12) {
                SettingsSidebar(selection: $navigation.tab)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 760, minHeight: 560)
        .tint(IslandTheme.accentDeep)
        .onAppear {
            loginModel.refresh()
            permissionModel.refresh()
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { message != nil },
                set: { presented in
                    if !presented {
                        message = nil
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                message = nil
            }
        } message: {
            Text(message ?? "")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.tab {
        case .general:
            GeneralSettingsView(config: config, loginModel: loginModel)
        case .folders:
            FolderSettingsView(config: config, showMessage: showMessage)
        case .launch:
            LaunchSettingsView(config: config, showMessage: showMessage)
        case .capture:
            CaptureSettingsView(config: config, permissionModel: permissionModel)
        case .about:
            AboutSettingsView()
        }
    }

    private func showMessage(_ text: String) {
        message = text
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsTab

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var primaryTabs: [SettingsTab] {
        [.general, .folders, .launch, .capture]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            brand

            VStack(alignment: .leading, spacing: 3) {
                Text("设置")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 10)
                    .padding(.bottom, 1)

                ForEach(primaryTabs) { tab in
                    SettingsNavItem(tab: tab, isSelected: selection == tab) {
                        selection = tab
                    }
                }
            }

            Spacer(minLength: 0)

            SettingsNavItem(tab: .about, isSelected: selection == .about) {
                selection = .about
            }

            Text("版本 \(version) · 开发预览")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .padding(.leading, 10)
                .padding(.bottom, 2)
        }
        .padding(12)
        .frame(width: 198)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            SettingsSurface(cornerRadius: 20, tint: IslandTheme.accent.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
    }

    private var brand: some View {
        HStack(spacing: 9) {
            IslandTheme.brandMark(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("栖岛")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(0.5)
                Text("ISLENEST")
                    .font(.system(size: 7.5, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 6)
        .padding(.top, 4)
    }
}

private struct SettingsNavItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? IslandTheme.accent : .secondary)
                    .frame(width: 23, height: 23)
                    .background(
                        isSelected
                            ? IslandTheme.accent.opacity(0.14)
                            : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )

                Text(tab.title)
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
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
