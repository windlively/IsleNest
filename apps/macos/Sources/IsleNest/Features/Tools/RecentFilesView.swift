import AppKit
import SwiftUI

struct RecentFilesView: View {
    @ObservedObject var store: RecentFilesStore
    @ObservedObject var model: IslandModel
    let actions: IslandActions

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 14) {
            header
            content
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            store.load()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(IslandTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    IslandTheme.accent.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("最近文件")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text("本机最近使用 · 数据不出本机")
                    .font(.system(size: 11))
                    .foregroundStyle(IslandTheme.textTertiary)
            }

            Spacer(minLength: 0)

            HeaderIconButton(
                symbol: "arrow.clockwise",
                label: "刷新最近文件",
                focusID: .recentRefresh,
                model: model,
                action: actions.refreshRecentFiles
            )
            HeaderIconButton(
                symbol: "chevron.left",
                label: "返回工具",
                focusID: .recentBack,
                model: model,
                action: actions.toggleRecentFiles
            )
            HeaderIconButton(
                symbol: "chevron.up",
                label: "收起栖岛",
                focusID: .collapse,
                model: model,
                action: actions.collapse
            )
        }
        .frame(height: 34)
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.files.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(IslandTheme.accent)
                Text("正在查找最近文件…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(IslandTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
        } else if store.files.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(IslandTheme.accent.opacity(0.85))
                    .frame(width: 46, height: 46)
                    .background(IslandTheme.accent.opacity(0.09), in: Circle())

                Text("最近没有文件记录")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text("打开过的文件会出现在这里，也可以点右上角刷新")
                    .font(.system(size: 11))
                    .foregroundStyle(IslandTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("最近 30 天")
                        .foregroundStyle(IslandTheme.textSecondary)
                    Text("\(store.files.count)")
                        .foregroundStyle(IslandTheme.textTertiary)
                        .monospacedDigit()
                    Spacer()
                    if store.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(IslandTheme.textTertiary)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .frame(height: 22)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(store.files) { file in
                        RecentFileTile(file: file, model: model, actions: actions)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(IslandTheme.divider).frame(height: 0.5)
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                Text("点击打开 · 右键可定位或复制路径")
                Spacer(minLength: 0)
                Text("esc").font(.system(size: 9.5, design: .monospaced))
                Text("返回")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(IslandTheme.textTertiary)
        }
    }
}

private struct RecentFileTile: View {
    let file: RecentFilesStore.RecentFile
    @ObservedObject var model: IslandModel
    let actions: IslandActions

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == .recentFile(file.url)
    }

    var body: some View {
        Button(action: { actions.openRecentFile(file.url) }) {
            VStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 27, height: 27)

                Text(file.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IslandTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(file.folderName)
                    .font(.system(size: 9))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .islandGlass(.quiet, cornerRadius: 12, active: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 12)
        .accessibilityLabel("打开最近文件 \(file.name)")
        .accessibilityHint(file.folderName)
        .contextMenu {
            Button("打开") { actions.openRecentFile(file.url) }
            Button("在 Finder 中显示") { actions.revealRecentFile(file.url) }
            Button("复制路径") { actions.copyRecentPath(file.url) }
        }
        .help("\(file.name)\n\(file.url.deletingLastPathComponent().path)")
    }
}
