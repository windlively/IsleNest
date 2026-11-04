import IsleNestCore
import SwiftUI

struct FolderSettingsView: View {
    @ObservedObject var config: ConfigStore
    let showMessage: (String) -> Void

    @State private var statuses: [UUID: FolderAvailability] = [:]

    var body: some View {
        SettingsPage(title: "文件夹", subtitle: "固定常用目录，展开即可打开", symbol: "folder") {
            SettingsCard(
                title: "常用文件夹",
                trailing: "\(config.folders.count) / \(ConfigStore.maxFolderCount)",
                footer: "每页显示 4 个，可在工具栏翻页访问。移除只删除快捷入口，不会删除磁盘上的文件。"
            ) {
                if config.folders.isEmpty {
                    SettingsRow {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("还没有固定文件夹")
                                    .font(.callout)
                                Text("添加后，展开首页即可一次点击打开。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    ForEach(
                        Array(config.folders.enumerated()),
                        id: \.element.id
                    ) { index, folder in
                        SettingsRow {
                            row(folder)
                        }

                        if index < config.folders.count - 1 {
                            SettingsDivider()
                        }
                    }
                }

                SettingsDivider()

                SettingsRow {
                    Button {
                        addFolders()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("添加文件夹…")
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(IslandTheme.accent)
                    .disabled(config.folders.count >= ConfigStore.maxFolderCount)
                }
            }
        }
        .onAppear(perform: refreshStatuses)
        .onChange(of: config.folders) { _, _ in
            refreshStatuses()
        }
    }

    private func row(_ folder: FavoriteFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(folder.abbreviatedPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            statusIndicator(for: folder)

            Menu {
                Button {
                    open(folder)
                } label: {
                    Label("打开", systemImage: "arrow.up.forward.app")
                }

                Button {
                    relocate(folder)
                } label: {
                    Label("重新定位…", systemImage: "location")
                }

                Button {
                    rename(folder)
                } label: {
                    Label("重命名…", systemImage: "pencil")
                }

                Divider()

                Button {
                    config.moveFolder(id: folder.id, by: -1)
                } label: {
                    Label("上移", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp(folder))

                Button {
                    config.moveFolder(id: folder.id, by: 1)
                } label: {
                    Label("下移", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown(folder))

                Divider()

                Button(role: .destructive) {
                    config.removeFolder(id: folder.id)
                } label: {
                    Label("移除快捷入口", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("文件夹操作")
            .accessibilityLabel("文件夹操作")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusIndicator(for folder: FavoriteFolder) -> some View {
        if let status = statuses[folder.id] {
            switch status {
            case .available:
                EmptyView()
            case .missingVolume:
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .help("设备未连接")
                    .accessibilityLabel("设备未连接")
            case .missing:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("目录不存在")
                    .accessibilityLabel("目录不存在")
            case .permissionDenied:
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                    .help("没有访问权限")
                    .accessibilityLabel("没有访问权限")
            case .unresolved:
                Image(systemName: "questionmark.folder")
                    .foregroundStyle(.orange)
                    .help("无法定位目录")
                    .accessibilityLabel("无法定位目录")
            }
        }
    }

    private func canMoveUp(_ folder: FavoriteFolder) -> Bool {
        config.folders.first?.id != folder.id
    }

    private func canMoveDown(_ folder: FavoriteFolder) -> Bool {
        config.folders.last?.id != folder.id
    }

    private func refreshStatuses() {
        var updated: [UUID: FolderAvailability] = [:]
        for folder in config.folders {
            updated[folder.id] = config.folderAvailability(id: folder.id)
        }
        statuses = updated
    }

    private func addFolders() {
        let remaining = ConfigStore.maxFolderCount - config.folders.count
        guard remaining > 0 else {
            showMessage(ConfigStoreError.folderLimitReached.localizedDescription)
            return
        }

        let urls = SystemPanels.chooseDirectories(
            limit: remaining,
            message: "选择要固定的文件夹（可在工具栏翻页访问）"
        )
        guard !urls.isEmpty else {
            return
        }

        var duplicates = 0
        var failures: [String] = []
        for url in urls {
            do {
                try config.addFolder(at: url)
            } catch ConfigStoreError.duplicateFolder {
                duplicates += 1
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        refreshStatuses()

        if !failures.isEmpty {
            showMessage(failures.joined(separator: "\n"))
        } else if duplicates > 0, duplicates == urls.count {
            showMessage("所选文件夹已经固定过了。")
        }
    }

    private func open(_ folder: FavoriteFolder) {
        if case .failure(let error) = WorkspaceService.openFolder(id: folder.id, config: config) {
            showMessage("无法打开「\(folder.title)」：\(error.localizedDescription)")
        }
    }

    private func relocate(_ folder: FavoriteFolder) {
        guard let url = SystemPanels.chooseDirectory(
            message: "为「\(folder.title)」选择新的位置",
            prompt: "重新定位"
        ) else {
            return
        }
        do {
            try config.relocateFolder(id: folder.id, to: url)
            refreshStatuses()
        } catch {
            showMessage(error.localizedDescription)
        }
    }

    private func rename(_ folder: FavoriteFolder) {
        guard let title = SystemPanels.rename(
            title: "重命名文件夹",
            message: "显示名称只影响栖岛首页，不会修改磁盘上的文件夹名。",
            current: folder.title
        ) else {
            return
        }
        config.renameFolder(id: folder.id, to: title)
    }
}
