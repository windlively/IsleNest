import AppKit
import IsleNestCore
import SwiftUI

struct HomeView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var model: IslandModel
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var recentFiles: RecentFilesStore
    let actions: IslandActions

    private var folders: ItemPage<FavoriteFolder> { ItemPage(config.folders, index: model.folderPage) }
    private var launchItems: ItemPage<LaunchItem> { ItemPage(config.launchItems, index: model.launchPage) }
    private var recentItems: [RecentFilesStore.RecentFile] { Array(recentFiles.files.prefix(3)) }

    var body: some View {
        VStack(spacing: 0) {
            header

            captureSection
                .padding(.top, 17)

            recentSection
                .padding(.top, 15)

            pinnedSection
                .padding(.top, 15)

            Spacer(minLength: 8)
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            recentFiles.load()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            IslandTheme.brandMark(size: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text("栖岛")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(IslandTheme.textPrimary)
                Text("ISLENEST")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(2.1)
                    .foregroundStyle(IslandTheme.textTertiary)
            }

            Spacer(minLength: 6)

            if timer.isActive {
                HeaderTimerChip(timer: timer, model: model, action: actions.togglePomodoro)
            } else {
                HeaderIconButton(
                    symbol: "timer",
                    label: "番茄钟",
                    focusID: .pomodoro,
                    model: model,
                    action: actions.togglePomodoro
                )
            }

            HeaderIconButton(
                symbol: "tray",
                label: config.shelfItems.isEmpty ? "文件暂存" : "文件暂存，\(config.shelfItems.count) 项",
                focusID: .shelf,
                model: model,
                action: actions.toggleShelf
            )
            .overlay(alignment: .topTrailing) {
                if !config.shelfItems.isEmpty {
                    Text(config.shelfItems.count > 9 ? "9+" : "\(config.shelfItems.count)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(IslandTheme.accent)
                        .frame(minWidth: 13, minHeight: 13)
                        .background(IslandTheme.badgeFill, in: Capsule())
                        .offset(x: 1, y: -1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

            WorkspaceEntryButton(model: model, action: actions.openWorkspace)

            HeaderIconButton(
                symbol: "chevron.up",
                label: "收起栖岛",
                focusID: .collapse,
                model: model,
                action: actions.collapse
            )
        }
        .frame(height: 32)
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("截屏与录制") {
                Text("⌘1–5")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 6) {
                captureTile(.region)
                captureTile(.window)
                captureTile(.display)
                captureTile(.scrolling)
                recordTile
                colorTile
            }
        }
    }

    private func captureTile(_ kind: CaptureKind) -> some View {
        IslandTileButton(
            focusID: .capture(kind),
            accessibilityLabel: kind.title,
            accessibilityHint: kind.hint,
            height: 62,
            prominent: kind == .region,
            model: model,
            action: { actions.capture(kind) }
        ) {
            VStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(kind == .region ? IslandTheme.accent : IslandTheme.textSecondary)
                Text(kind.shortTitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(kind == .region ? IslandTheme.textPrimary : IslandTheme.textSecondary)
            }
        }
        .help("\(kind.hint) · ⌘\(kind.shortcutNumber ?? 1)（面板内）")
    }

    private var recordTile: some View {
        IslandTileButton(
            focusID: .record,
            accessibilityLabel: "区域录屏",
            accessibilityHint: "框选区域并录制为视频",
            height: 62,
            model: model,
            action: actions.recordRegion
        ) {
            VStack(spacing: 6) {
                Image(systemName: "record.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(IslandTheme.error.opacity(0.9))
                Text("录屏")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(IslandTheme.textSecondary)
            }
        }
        .help("区域录屏 · ⌘5（面板内）")
    }

    private var colorTile: some View {
        IslandTileButton(
            focusID: .colorPicker,
            accessibilityLabel: "屏幕取色",
            accessibilityHint: "吸取屏幕颜色并复制 HEX 与 RGB",
            height: 62,
            model: model,
            action: actions.sampleColor
        ) {
            VStack(spacing: 6) {
                Image(systemName: "eyedropper")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(IslandTheme.textSecondary)
                Text("取色")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(IslandTheme.textSecondary)
            }
        }
        .help("吸取屏幕颜色，复制 HEX 与 RGB")
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("最近") {
                Button("工作台查看全部") {
                    actions.openWorkspace()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(IslandTheme.textTertiary)
                .padding(.horizontal, 4)
                .frame(height: 20)
                .contentShape(Rectangle())
                .help("在栖岛工作台查看最近文件与历史")
            }

            if recentFiles.isLoading, !recentFiles.hasLoaded {
                RecentLoadingStrip()
            } else if recentItems.isEmpty {
                RecentEmptyStrip(model: model, openWorkspace: actions.openWorkspace)
            } else {
                HStack(spacing: 7) {
                    ForEach(recentItems) { file in
                        RecentFileChip(
                            file: file,
                            model: model,
                            open: { actions.openRecentFile(file.url) }
                        )
                    }
                }
            }
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("固定") {
                HStack(spacing: 5) {
                    if folders.count > 1 {
                        PageChip(
                            label: "\(model.folderPage + 1)/\(folders.count)",
                            symbol: "folder",
                            focusID: .nextFolderPage,
                            model: model
                        ) {
                            actions.nextFolderPage()
                        }
                    }
                    if launchItems.count > 1 {
                        PageChip(
                            label: "\(model.launchPage + 1)/\(launchItems.count)",
                            symbol: "square.grid.2x2",
                            focusID: .nextLaunchPage,
                            model: model
                        ) {
                            actions.nextLaunchPage()
                        }
                    }
                    if folders.count <= 1, launchItems.count <= 1 {
                        Text("\(config.folders.count) 文件夹 · \(config.launchItems.count) 启动")
                            .font(.system(size: 9.5))
                            .foregroundStyle(IslandTheme.textTertiary)
                            .monospacedDigit()
                    }
                }
            }

            VStack(spacing: 6) {
                if folders.items.isEmpty {
                    emptyPinnedRow("固定常用文件夹") {
                        PinnedAddButton(
                            title: "添加文件夹",
                            accessibilityTitle: "添加文件夹",
                            focusID: .addFolder,
                            model: model,
                            action: actions.addFolder
                        )
                    }
                } else {
                    HStack(spacing: 6) {
                        ForEach(folders.items) { folder in
                            folderTile(folder)
                        }
                        if config.folders.count < ConfigStore.homeItemCount {
                            addTile(
                                title: "添加文件夹",
                                focusID: .addFolder,
                                action: actions.addFolder
                            )
                        }
                    }
                }

                if launchItems.items.isEmpty {
                    emptyPinnedRow("固定应用或网页") {
                        PinnedAddButton(
                            title: "应用",
                            accessibilityTitle: "添加应用",
                            focusID: .addLaunch,
                            model: model,
                            action: actions.addLaunch
                        )
                        PinnedAddButton(
                            title: "网页",
                            accessibilityTitle: "添加网页",
                            focusID: .addWebsite,
                            model: model,
                            action: actions.addWebsite
                        )
                    }
                } else {
                    HStack(spacing: 6) {
                        ForEach(launchItems.items) { item in
                            launchTile(item)
                        }
                        if config.launchItems.count < ConfigStore.homeItemCount {
                            addTile(
                                title: "添加应用",
                                focusID: .addLaunch,
                                action: actions.addLaunch
                            )
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(IslandTheme.divider).frame(height: 0.5)
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.to.line.compact").font(.system(size: 10))
                Text("拖入固定 · 文件暂存")
                Spacer(minLength: 0)
                Text("esc").font(.system(size: 9.5, design: .monospaced))
                Text("收起")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(IslandTheme.textTertiary)
        }
        .help("文件夹、应用与网页会固定，其他文件会加入暂存")
    }

    private func folderTile(_ folder: FavoriteFolder) -> some View {
        IslandTileButton(
            focusID: .folder(folder.id),
            accessibilityLabel: "打开文件夹 \(folder.title)",
            accessibilityHint: folder.abbreviatedPath,
            height: 32,
            quiet: true,
            model: model,
            action: { actions.openFolder(folder.id) }
        ) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(IslandTheme.accent)
                Text(folder.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IslandTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 8)
        }
        .help(folder.abbreviatedPath)
        .contextMenu {
            Button("打开", action: { actions.openFolder(folder.id) })
            Button("移到最前") { config.moveFolder(id: folder.id, by: -ConfigStore.maxFolderCount) }
            Divider()
            Button("移除快捷入口", role: .destructive) { config.removeFolder(id: folder.id) }
        }
    }

    private func launchTile(_ item: LaunchItem) -> some View {
        IslandTileButton(
            focusID: .launch(item.id),
            accessibilityLabel: "启动 \(item.title)",
            accessibilityHint: item.kind == .website ? item.urlString : "打开应用",
            height: 32,
            quiet: true,
            model: model,
            action: { actions.openLaunch(item.id) }
        ) {
            HStack(spacing: 6) {
                if let icon = AppIconCache.shared.icon(for: item) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 15, height: 15)
                } else {
                    Image(systemName: item.kind == .website ? "globe" : "app.dashed")
                        .font(.system(size: 11))
                        .foregroundStyle(IslandTheme.textSecondary)
                }
                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IslandTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 8)
        }
        .help(item.kind == .website ? (item.urlString ?? item.title) : item.title)
        .contextMenu {
            Button("打开", action: { actions.openLaunch(item.id) })
            Button("移到最前") { config.moveLaunchItem(id: item.id, by: -ConfigStore.maxLaunchItemCount) }
            Divider()
            Button("移除快捷入口", role: .destructive) { config.removeLaunchItem(id: item.id) }
        }
    }

    private func addTile(
        title: String,
        focusID: IslandFocusID,
        action: @escaping () -> Void
    ) -> some View {
        IslandTileButton(
            focusID: focusID,
            accessibilityLabel: title,
            accessibilityHint: nil,
            height: 32,
            quiet: true,
            model: model,
            action: action
        ) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(IslandTheme.textTertiary)
        }
    }

    private func emptyPinnedRow<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "pin")
                .font(.system(size: 10))
                .foregroundStyle(IslandTheme.textTertiary)
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(IslandTheme.textTertiary)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(IslandTheme.contrast(0.025), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    IslandTheme.contrast(0.09),
                    style: StrokeStyle(lineWidth: 0.75, dash: [3, 4])
                )
        }
    }

    private func sectionLabel<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(IslandTheme.accent.opacity(0.75))
                .frame(width: 3, height: 11)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(IslandTheme.textSecondary)
            Spacer(minLength: 6)
            trailing()
        }
        .frame(height: 20)
    }
}

private struct WorkspaceEntryButton: View {
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == .workspace
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 10.5, weight: .medium))
                Text("工作台")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(isHovered ? IslandTheme.textPrimary : IslandTheme.textSecondary)
            .padding(.horizontal, 8)
            .frame(height: 30)
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
        .help("打开栖岛工作台")
        .accessibilityLabel("打开栖岛工作台")
    }
}

private struct RecentFileChip: View {
    let file: RecentFilesStore.RecentFile
    @ObservedObject var model: IslandModel
    let open: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == .recentFile(file.url)
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 7) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(file.name)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(IslandTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(file.folderName)
                        .font(.system(size: 9))
                        .foregroundStyle(IslandTheme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .islandGlass(.quiet, cornerRadius: 11, active: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 11)
        .help(file.url.path)
        .accessibilityLabel("打开最近文件 \(file.name)")
        .contextMenu {
            Button("打开", action: open)
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
            Button("复制路径") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
            }
        }
    }
}

private struct RecentLoadingStrip: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text("正在读取最近使用记录…")
                .font(.system(size: 10.5))
                .foregroundStyle(IslandTheme.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .islandGlass(.quiet, cornerRadius: 11, interactive: false)
    }
}

private struct RecentEmptyStrip: View {
    @ObservedObject var model: IslandModel
    let openWorkspace: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == .workspace
    }

    var body: some View {
        Button(action: openWorkspace) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .foregroundStyle(IslandTheme.accent)
                Text("最近使用的文件会出现在这里")
                    .font(.system(size: 10.5))
                    .foregroundStyle(IslandTheme.textTertiary)
                Spacer(minLength: 0)
                Text("工作台")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(IslandTheme.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(IslandTheme.textTertiary)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .islandGlass(.quiet, cornerRadius: 11, active: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 11)
        .help("打开栖岛工作台")
    }
}

private struct PageChip: View {
    let label: String
    let symbol: String
    let focusID: IslandFocusID
    @ObservedObject var model: IslandModel
    let action: () -> Void

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == focusID
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .semibold))
            }
            .foregroundStyle(IslandTheme.textTertiary)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(IslandTheme.tileFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .islandFocusRing(isSelected, cornerRadius: 10)
        .help("切换到下一组")
    }
}

private struct PinnedAddButton: View {
    let title: String
    let accessibilityTitle: String
    let focusID: IslandFocusID
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == focusID
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovered ? IslandTheme.accent : IslandTheme.textSecondary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                IslandTheme.accent.opacity(isHovered ? 0.12 : 0.06),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 11)
        .accessibilityLabel(accessibilityTitle)
    }
}

private struct HeaderTimerChip: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == .pomodoro
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: timer.phase == .focus ? "timer" : "cup.and.saucer")
                    .font(.system(size: 10.5, weight: .medium))
                Text(timer.timeText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(IslandTheme.accent)
            .padding(.horizontal, 8)
            .frame(height: 30)
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
        .help("番茄钟 · \(timer.phase.title) \(timer.timeText)")
        .accessibilityLabel("番茄钟，\(timer.phase.title)剩余 \(timer.timeText)")
    }
}
