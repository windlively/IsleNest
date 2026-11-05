import IsleNestCore
import SwiftUI

struct WorkspaceSettingsView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var navigation: WorkspaceNavigation

    @StateObject private var loginModel = LoginItemModel()
    @StateObject private var permissionModel = ScreenPermissionModel()
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WorkspacePageHeader(
                title: "设置",
                subtitle: "外观、截屏与快捷入口",
                symbol: "gearshape"
            ) {
                WorkspaceSegmentedTabs(
                    items: SettingsTab.allCases,
                    title: \.title,
                    symbol: \.symbol,
                    selection: $navigation.settingsTab
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        switch navigation.settingsTab {
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
