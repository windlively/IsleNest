import IsleNestCore
import SwiftUI

struct ShelfView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var model: IslandModel
    let actions: IslandActions

    @State private var isDropTargeted = false

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 16) {
            header
            dropZone
            content
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .dropDestination(for: URL.self) { urls, _ in
            let accepted = actions.shelfDrop(urls)
            isDropTargeted = false
            return accepted
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.14)) {
                isDropTargeted = targeted
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(IslandTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    IslandTheme.accent.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("文件暂存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text("原文件保持原位，拖出即可使用")
                    .font(.system(size: 11))
                    .foregroundStyle(IslandTheme.textTertiary)
            }

            Spacer(minLength: 0)

            HeaderIconButton(
                symbol: "chevron.left",
                label: "返回工具",
                focusID: .shelfBack,
                model: model,
                action: { actions.toggleShelf() }
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

    private var dropZone: some View {
        Button(action: actions.addShelfFiles) {
            HStack(spacing: 11) {
                Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus.circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(IslandTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isDropTargeted ? "松手，加入暂存" : "拖入文件或文件夹")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(IslandTheme.textPrimary)
                    Text("或点击选择 · 不会移动原文件")
                        .font(.system(size: 10.5))
                        .foregroundStyle(IslandTheme.textTertiary)
                }

                Spacer(minLength: 4)

                Text("\(config.shelfItems.count) / \(ConfigStore.maxShelfItemCount)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(IslandTheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        isDropTargeted
                            ? IslandTheme.accent.opacity(0.12)
                            : IslandTheme.tileFill
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? IslandTheme.accent.opacity(0.7) : IslandTheme.contrast(0.12),
                        style: StrokeStyle(lineWidth: 0.75, dash: isDropTargeted ? [] : [3, 4])
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .islandFocusRing(
            model.keyboardFocusVisible && model.selectedFocus == .shelfAdd,
            cornerRadius: 13
        )
        .accessibilityLabel("添加文件到暂存")
        .accessibilityHint("也可以直接把文件拖进面板")
    }

    @ViewBuilder
    private var content: some View {
        if config.shelfItems.isEmpty {
            emptyState
        } else {
            VStack(spacing: 9) {
                HStack(spacing: 6) {
                    Text("暂存项目")
                        .foregroundStyle(IslandTheme.textSecondary)
                    Text("\(config.shelfItems.count)")
                        .foregroundStyle(IslandTheme.textTertiary)
                        .monospacedDigit()
                    Spacer()
                    Button(action: actions.clearShelf) {
                        Text("清空")
                            .foregroundStyle(IslandTheme.textTertiary)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(IslandTheme.tileFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .islandFocusRing(
                        model.keyboardFocusVisible && model.selectedFocus == .shelfClear,
                        cornerRadius: 12
                    )
                    .accessibilityLabel("清空暂存")
                }
                .font(.system(size: 12, weight: .medium))
                .frame(height: 22)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(config.shelfItems) { item in
                        ShelfItemTile(item: item, model: model, actions: actions)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(IslandTheme.accent.opacity(0.85))
                .frame(width: 46, height: 46)
                .background(IslandTheme.accent.opacity(0.09), in: Circle())

            Text("暂存区是空的")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(IslandTheme.textPrimary)

            Text("PDF、图片、压缩包等都可以先放这里")
                .font(.system(size: 11))
                .foregroundStyle(IslandTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(IslandTheme.divider).frame(height: 0.5)
            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                Text("拖出即可使用 · 原文件保持原位")
                Spacer(minLength: 0)
                Text("esc").font(.system(size: 9.5, design: .monospaced))
                Text("返回")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(IslandTheme.textTertiary)
        }
    }

}

private struct ShelfItemTile: View {
    let item: ShelfItem
    @ObservedObject var model: IslandModel
    let actions: IslandActions

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == .shelfItem(item.id)
    }

    private var isMissing: Bool {
        !FileManager.default.fileExists(atPath: item.path)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: { actions.openShelfItem(item.id) }) {
                VStack(spacing: 7) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                        .opacity(isMissing ? 0.45 : 1)

                    Text(item.title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(isMissing ? IslandTheme.textTertiary : IslandTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .islandGlass(.quiet, cornerRadius: 12, active: isHovered)
                .overlay(alignment: .topLeading) {
                    if isMissing {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(IslandTheme.warning)
                            .padding(6)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(IslandPressStyle())
            .accessibilityLabel("打开暂存文件 \(item.title)")
            .accessibilityHint(item.abbreviatedPath)

            if isHovered {
                Button(action: { actions.removeShelfItem(item.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(IslandTheme.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(IslandTheme.panelFill, in: Circle())
                        .overlay(Circle().strokeBorder(IslandTheme.contrast(0.08), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .accessibilityLabel("从暂存移除 \(item.title)")
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onDrag {
            NSItemProvider(contentsOf: URL(fileURLWithPath: item.path)) ?? NSItemProvider()
        }
        .islandFocusRing(isSelected, cornerRadius: 12)
        .contextMenu {
            Button("打开") { actions.openShelfItem(item.id) }
            Button("在 Finder 中显示") { actions.revealShelfItem(item.id) }
            Button("复制路径") { actions.copyShelfPath(item.id) }
            Button("分享…") { actions.shareShelfItem(item.id) }
            Divider()
            Button("从暂存移除", role: .destructive) { actions.removeShelfItem(item.id) }
        }
        .help("\(item.title)\n\(item.abbreviatedPath)\n拖出即可使用")
    }
}
