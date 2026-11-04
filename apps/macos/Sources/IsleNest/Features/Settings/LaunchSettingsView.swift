import AppKit
import IsleNestCore
import SwiftUI

struct LaunchSettingsView: View {
    @ObservedObject var config: ConfigStore
    let showMessage: (String) -> Void

    var body: some View {
        SettingsPage(title: "快捷启动", subtitle: "常用应用与网页，一键启动", symbol: "square.grid.2x2") {
            SettingsCard(
                title: "快捷启动",
                trailing: "\(config.launchItems.count) / \(ConfigStore.maxLaunchItemCount)",
                footer: "每页显示 4 个，可在工具栏翻页访问。网页仅接受 http / https 地址，不提供任意命令执行。"
            ) {
                if config.launchItems.isEmpty {
                    SettingsRow {
                        HStack(spacing: 10) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("还没有快捷启动")
                                    .font(.callout)
                                Text("添加应用或网页，展开首页即可启动。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    ForEach(
                        Array(config.launchItems.enumerated()),
                        id: \.element.id
                    ) { index, item in
                        SettingsRow {
                            row(item)
                        }

                        if index < config.launchItems.count - 1 {
                            SettingsDivider()
                        }
                    }
                }

                SettingsDivider()

                SettingsRow {
                    HStack(spacing: 14) {
                        Button {
                            addApplications()
                        } label: {
                            Label("添加应用…", systemImage: "plus.square.on.square")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(IslandTheme.accent)
                        .disabled(isFull)

                        Rectangle()
                            .fill(IslandTheme.divider)
                            .frame(width: 0.5, height: 16)

                        Button {
                            addWebsite()
                        } label: {
                            Label("添加网页…", systemImage: "globe")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(IslandTheme.accent)
                        .disabled(isFull)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var isFull: Bool {
        config.launchItems.count >= ConfigStore.maxLaunchItemCount
    }

    private func row(_ item: LaunchItem) -> some View {
        HStack(spacing: 10) {
            icon(for: item)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(detail(for: item))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if isApplicationMissing(item) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("应用已不存在")
                    .accessibilityLabel("应用已不存在")
            }

            Menu {
                Button {
                    open(item)
                } label: {
                    Label("打开", systemImage: "arrow.up.forward.app")
                }

                Button {
                    rename(item)
                } label: {
                    Label("重命名…", systemImage: "pencil")
                }

                if item.kind == .website {
                    Button {
                        editWebsite(item)
                    } label: {
                        Label("编辑网址…", systemImage: "link")
                    }
                }

                Divider()

                Button {
                    config.moveLaunchItem(id: item.id, by: -1)
                } label: {
                    Label("上移", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp(item))

                Button {
                    config.moveLaunchItem(id: item.id, by: 1)
                } label: {
                    Label("下移", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown(item))

                Divider()

                Button(role: .destructive) {
                    config.removeLaunchItem(id: item.id)
                } label: {
                    Label("移除快捷启动", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("快捷启动操作")
            .accessibilityLabel("快捷启动操作")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func icon(for item: LaunchItem) -> some View {
        if item.kind == .application, let appIcon = AppIconCache.shared.icon(for: item) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: item.kind == .website ? "globe" : "app.fill")
                .font(.system(size: 15))
                .foregroundStyle(.tint)
        }
    }

    private func detail(for item: LaunchItem) -> String {
        switch item.kind {
        case .website:
            return item.urlString ?? "网页"
        case .application:
            return item.bundleIdentifier ?? "应用"
        }
    }

    private func isApplicationMissing(_ item: LaunchItem) -> Bool {
        guard item.kind == .application else {
            return false
        }
        if item.applicationURL != nil {
            return false
        }
        if let bundleID = item.bundleIdentifier,
           NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
            return false
        }
        return true
    }

    private func canMoveUp(_ item: LaunchItem) -> Bool {
        config.launchItems.first?.id != item.id
    }

    private func canMoveDown(_ item: LaunchItem) -> Bool {
        config.launchItems.last?.id != item.id
    }

    private func addApplications() {
        guard !isFull else {
            showMessage(ConfigStoreError.launchLimitReached.localizedDescription)
            return
        }
        let remaining = ConfigStore.maxLaunchItemCount - config.launchItems.count
        let urls = SystemPanels.chooseApplications(limit: remaining)
        guard !urls.isEmpty else {
            return
        }

        do {
            let added = try config.addApplications(at: urls)
            if added.isEmpty {
                showMessage("没有添加应用：可能已经在列表里了。")
            }
        } catch {
            showMessage(error.localizedDescription)
        }
    }

    private func addWebsite() {
        guard !isFull else {
            showMessage(ConfigStoreError.launchLimitReached.localizedDescription)
            return
        }
        guard let result = SystemPanels.website(
            title: "添加网页",
            message: "仅支持 http 或 https 网址。",
            initialTitle: "",
            initialURL: ""
        ) else {
            return
        }
        do {
            try config.addWebsite(title: result.title, urlString: result.urlString)
        } catch {
            showMessage(error.localizedDescription)
        }
    }

    private func editWebsite(_ item: LaunchItem) {
        guard let result = SystemPanels.website(
            title: "编辑网页",
            message: "仅支持 http 或 https 网址。",
            initialTitle: item.title,
            initialURL: item.urlString ?? ""
        ) else {
            return
        }
        do {
            try config.updateWebsite(
                id: item.id,
                title: result.title,
                urlString: result.urlString
            )
        } catch {
            showMessage(error.localizedDescription)
        }
    }

    private func rename(_ item: LaunchItem) {
        guard let title = SystemPanels.rename(
            title: "重命名快捷启动",
            message: "名称只影响栖岛首页显示。",
            current: item.title
        ) else {
            return
        }
        config.renameLaunchItem(id: item.id, to: title)
    }

    private func open(_ item: LaunchItem) {
        if case .failure(let error) = WorkspaceService.openLaunchItem(item) {
            showMessage("无法启动「\(item.title)」：\(error.localizedDescription)")
        }
    }
}
