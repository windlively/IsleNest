import IsleNestCore
import SwiftUI

struct HomeView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var model: IslandModel
    @ObservedObject var timer: PomodoroTimer
    let actions: IslandActions

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)
    private var folders: ItemPage<FavoriteFolder> { ItemPage(config.folders, index: model.folderPage) }
    private var launchItems: ItemPage<LaunchItem> { ItemPage(config.launchItems, index: model.launchPage) }

    var body: some View {
        VStack(spacing: 0) {
            header
            captureSection.padding(.top, 18)
            quickLocations.padding(.top, 6)
            folderSection.padding(.top, 14)
            launchSection.padding(.top, 14)
            Spacer(minLength: 6)
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 10) {
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
            Spacer(minLength: 0)

            HStack(spacing: 5) {
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
                    symbol: "clock.arrow.circlepath",
                    label: "最近文件",
                    focusID: .recentFiles,
                    model: model,
                    action: actions.toggleRecentFiles
                )
                HeaderIconButton(
                    symbol: "eyedropper",
                    label: "屏幕取色",
                    focusID: .colorPicker,
                    model: model,
                    action: actions.sampleColor
                )
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
                HeaderIconButton(symbol: "gearshape", label: "设置", focusID: .settings,
                                 model: model, action: actions.openSettings)
                Rectangle().fill(IslandTheme.divider).frame(width: 1, height: 12).padding(.horizontal, 3)
                HeaderIconButton(symbol: "chevron.up", label: "收起栖岛", focusID: .collapse,
                                 model: model, action: actions.collapse)
            }
        }
        .frame(height: 34)
    }

    private var captureSection: some View {
        VStack(spacing: 0) {
            IslandTileButton(
                focusID: .capture(.region), accessibilityLabel: CaptureKind.region.title,
                accessibilityHint: CaptureKind.region.hint, height: 65, quiet: true,
                model: model, action: { actions.capture(.region) }
            ) {
                HStack(spacing: 12) {
                    Image(systemName: CaptureKind.region.symbol)
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(IslandTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(IslandTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(IslandTheme.accent.opacity(0.12), lineWidth: 0.5)
                        }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("区域截屏").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(IslandTheme.textPrimary)
                        Text("框选屏幕，留住所需")
                            .font(.system(size: 11)).foregroundStyle(IslandTheme.textTertiary)
                    }
                    Spacer(minLength: 0)
                    ShortcutKey(title: "⌘1")
                }
                .padding(.horizontal, 13)
            }
            .help("拖动框选屏幕区域 · ⌘1（面板内）")

            Rectangle().fill(IslandTheme.divider).frame(height: 0.5).padding(.horizontal, 14)

            HStack(spacing: 0) {
                captureButton(.window)
                captureButton(.display)
                captureButton(.scrolling)
                recordButton
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .islandGlass(.hero, cornerRadius: 17, interactive: false)
    }

    private func captureButton(_ kind: CaptureKind) -> some View {
        IslandTileButton(
            focusID: .capture(kind), accessibilityLabel: kind.title, accessibilityHint: kind.hint,
            height: 44, quiet: true, model: model, action: { actions.capture(kind) }
        ) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol).font(.system(size: 12, weight: .regular))
                    .foregroundStyle(IslandTheme.textSecondary)
                Text(kind.shortTitle).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IslandTheme.textSecondary)
                Text("⌘\(kind.shortcutNumber ?? 1)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .help("\(kind.hint) · ⌘\(kind.shortcutNumber ?? 1)（面板内）")
    }

    private var recordButton: some View {
        IslandTileButton(
            focusID: .record, accessibilityLabel: "区域录屏",
            accessibilityHint: "框选区域并录制为视频", height: 44, quiet: true,
            model: model, action: actions.recordRegion
        ) {
            HStack(spacing: 6) {
                Image(systemName: "record.circle")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(IslandTheme.error.opacity(0.9))
                Text("录屏").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IslandTheme.textSecondary)
                Text("⌘5").font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .help("区域录屏 · ⌘5（面板内）")
    }

    private var quickLocations: some View {
        HStack(spacing: 2) {
            ForEach(QuickLocation.allCases) { location in
                IslandTileButton(
                    focusID: .location(location), accessibilityLabel: "打开\(location.title)",
                    accessibilityHint: "在 Finder 中打开", height: 32, quiet: true, model: model,
                    action: { actions.openLocation(location) }
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: location.symbol).font(.system(size: 11))
                            .foregroundStyle(IslandTheme.textTertiary)
                        Text(location.title).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(IslandTheme.textSecondary)
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

    private var folderSection: some View {
        VStack(spacing: 8) {
            sectionHeading("固定文件夹", count: config.folders.count, page: folders.index, pages: folders.count,
                           pageID: .nextFolderPage, next: actions.nextFolderPage,
                           manageID: .manageFolders, manage: actions.manageFolders)
            if config.folders.isEmpty {
                EmptySectionButton(symbol: "folder", title: "固定常用文件夹",
                                   detail: "拖入文件夹，或点击选择", focusID: .addFolder,
                                   model: model, action: actions.addFolder)
            } else {
                IslandGlassContainer(spacing: 8) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(folders.items) { folder in
                            IslandTileButton(focusID: .folder(folder.id), accessibilityLabel: "打开文件夹 \(folder.title)",
                                             accessibilityHint: folder.abbreviatedPath, height: 64, card: true, model: model,
                                             action: { actions.openFolder(folder.id) }) {
                                VStack(spacing: 7) {
                                    Image(systemName: "folder.fill").font(.system(size: 24, weight: .regular))
                                        .foregroundStyle(IslandTheme.accent)
                                    Text(folder.title).font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(IslandTheme.textPrimary)
                                        .lineLimit(1).truncationMode(.middle)
                                }.padding(.horizontal, 6)
                            }
                            .help(folder.abbreviatedPath)
                            .contextMenu {
                                Button("打开", action: { actions.openFolder(folder.id) })
                                Button("移到最前") { config.moveFolder(id: folder.id, by: -ConfigStore.maxFolderCount) }
                                Divider()
                                Button("移除快捷入口", role: .destructive) { config.removeFolder(id: folder.id) }
                            }
                        }
                        if config.folders.count < ConfigStore.homeItemCount {
                            IslandTileButton(focusID: .addFolder, accessibilityLabel: "添加文件夹", accessibilityHint: nil,
                                             height: 64, card: true, model: model, action: actions.addFolder) {
                                AddTileContent(title: "添加")
                            }
                        }
                    }
                }
            }
        }
    }

    private var launchSection: some View {
        VStack(spacing: 8) {
            sectionHeading("快捷启动", count: config.launchItems.count, page: launchItems.index, pages: launchItems.count,
                           pageID: .nextLaunchPage, next: actions.nextLaunchPage,
                           manageID: .editLaunch, manage: actions.editLaunch)
            if config.launchItems.isEmpty {
                HStack(spacing: 0) {
                    IslandTileButton(focusID: .addLaunch, accessibilityLabel: "添加应用", accessibilityHint: nil,
                                     height: 64, quiet: true, model: model, action: actions.addLaunch) {
                        Label("添加应用", systemImage: "plus.app").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(IslandTheme.textSecondary)
                    }
                    Rectangle().fill(IslandTheme.divider).frame(width: 0.5, height: 24)
                    IslandTileButton(focusID: .addWebsite, accessibilityLabel: "添加网页", accessibilityHint: nil,
                                     height: 64, quiet: true, model: model, action: actions.addWebsite) {
                        Label("添加网页", systemImage: "link").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(IslandTheme.textSecondary)
                    }
                }
                .islandGlass(.tile, cornerRadius: 12, interactive: false)
            } else {
                IslandGlassContainer(spacing: 8) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(launchItems.items) { item in
                            IslandTileButton(focusID: .launch(item.id), accessibilityLabel: "启动 \(item.title)",
                                             accessibilityHint: item.kind == .website ? item.urlString : "打开应用",
                                             height: 64, card: true, model: model, action: { actions.openLaunch(item.id) }) {
                                VStack(spacing: 6) {
                                    if let icon = AppIconCache.shared.icon(for: item) {
                                        Image(nsImage: icon).resizable().interpolation(.high).frame(width: 30, height: 30)
                                    } else {
                                        Image(systemName: item.kind == .website ? "globe" : "app.dashed")
                                            .font(.system(size: 22)).foregroundStyle(IslandTheme.textSecondary)
                                            .frame(height: 27)
                                    }
                                    Text(item.title).font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(IslandTheme.textPrimary).lineLimit(1).truncationMode(.middle)
                                }.padding(.horizontal, 6)
                            }
                            .contextMenu {
                                Button("打开", action: { actions.openLaunch(item.id) })
                                Button("移到最前") { config.moveLaunchItem(id: item.id, by: -ConfigStore.maxLaunchItemCount) }
                                Divider()
                                Button("移除快捷入口", role: .destructive) { config.removeLaunchItem(id: item.id) }
                            }
                        }
                        if config.launchItems.count < ConfigStore.homeItemCount {
                            IslandTileButton(focusID: .addLaunch, accessibilityLabel: "添加应用", accessibilityHint: nil,
                                             height: 64, card: true, model: model, action: actions.addLaunch) {
                                AddTileContent(title: "添加")
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeading(_ title: String, count: Int, page: Int, pages: Int,
                                pageID: IslandFocusID, next: @escaping () -> Void,
                                manageID: IslandFocusID, manage: @escaping () -> Void) -> some View {

        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(IslandTheme.accent.opacity(0.75))
                .frame(width: 3, height: 11)
            Text(title).foregroundStyle(IslandTheme.textSecondary)
            if count > 0 {
                Text("\(count)").foregroundStyle(IslandTheme.textTertiary).monospacedDigit()
            }
            Spacer()
            if pages > 1 {
                Button(action: next) {
                    HStack(spacing: 4) {
                        Text("\(page + 1) / \(pages)").monospacedDigit()
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    }.padding(.horizontal, 8).frame(height: 24)
                        .background(IslandTheme.tileFill, in: Capsule())
                }
                .buttonStyle(.plain).foregroundStyle(IslandTheme.accent)
                .islandFocusRing(model.keyboardFocusVisible && model.selectedFocus == pageID, cornerRadius: 12)
                .accessibilityLabel("\(title)下一页，当前第 \(page + 1) 页，共 \(pages) 页")
            }
            Button("管理", action: manage)
                .buttonStyle(.plain).foregroundStyle(IslandTheme.textTertiary)
                .padding(.horizontal, 4).frame(height: 24)
                .islandFocusRing(model.keyboardFocusVisible && model.selectedFocus == manageID, cornerRadius: 6)
                .accessibilityLabel("管理\(title)")
        }
        .font(.system(size: 11, weight: .medium))
        .frame(height: 20)
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
