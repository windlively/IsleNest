import IsleNestCore
import AppKit
import SwiftUI

struct WorkspaceFilesView: View {
    let services: WorkspaceServices
    let actions: WorkspaceActions
    @ObservedObject var navigation: WorkspaceNavigation
    let showToast: (WorkspaceToast.Kind, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkspacePageHeader(
                title: "文件",
                subtitle: "文件矩阵、大文件与空间清理",
                symbol: "folder"
            ) {
                WorkspaceSegmentedTabs(
                    items: WorkspaceFilesTab.allCases,
                    title: \.title,
                    symbol: \.symbol,
                    selection: $navigation.filesTab
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            switch navigation.filesTab {
            case .matrix:
                WorkspaceMatrixPage(
                    scanner: services.fileMatrix,
                    reveal: actions.revealFile,
                    showToast: showToast
                )
            case .largeFiles:
                WorkspaceLargeFilesPage(
                    scanner: services.largeFileScanner,
                    reveal: actions.revealFile,
                    showToast: showToast
                )
            }
        }
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WorkspaceMatrixPage: View {
    @ObservedObject var scanner: FileMatrixScanner
    let reveal: (URL) -> Void
    let showToast: (WorkspaceToast.Kind, String) -> Void

    @State private var hoveredURL: URL?
    @State private var selectedURL: URL?

    private var focusedNode: FileMatrixScanner.Node? {
        if let hoveredURL, let node = scanner.nodes.first(where: { $0.url == hoveredURL }) {
            return node
        }
        if let selectedURL, let node = scanner.nodes.first(where: { $0.url == selectedURL }) {
            return node
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 10) {
            toolbar
            HStack(alignment: .top, spacing: 12) {
                matrixArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                inspector
                    .frame(width: 272)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 22)
        .onAppear {
            scanner.prepareRoot()
        }
        .onChange(of: scanner.currentURL) { _, _ in
            hoveredURL = nil
            selectedURL = nil
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                scanner.goBack()
            } label: {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(!scanner.canGoBack)
            .help("返回上一级")

            Text(scanner.displayPath)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(scanner.currentURL?.path ?? "")

            if scanner.isScanning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("已检查 \(scanner.scannedCount) 个文件")
                        .font(.system(size: 9.5))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else if scanner.totalSize > 0 {
                Text("共 \(ByteFormatting.size(scanner.totalSize)) · \(scanner.nodes.count) 项")
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            } else if !scanner.hasScanned {
                Text("尚未扫描")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }

            Button {
                if scanner.isScanning {
                    scanner.cancel()
                } else {
                    scanner.refresh()
                }
            } label: {
                Image(systemName: scanner.isScanning ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(scanner.currentURL == nil)
            .help(scanner.isScanning ? "取消扫描" : (scanner.hasScanned ? "重新扫描" : "开始扫描"))
        }
        .frame(height: 26)
    }

    private var matrixArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.028))

            if scanner.isScanning {
                scanningState
            } else if let error = scanner.errorText {
                WorkspaceEmptyState(
                    symbol: "exclamationmark.triangle",
                    title: "无法读取此文件夹",
                    detail: error,
                    actionTitle: "重试",
                    action: { scanner.refresh() }
                )
            } else if !scanner.hasScanned {
                WorkspaceEmptyState(
                    symbol: "square.grid.3x3",
                    title: "文件矩阵",
                    detail: "点击开始扫描后，按体积显示主目录中的文件夹与文件。只读取文件大小，跳过隐藏项与符号链接；首次访问桌面、文稿等受保护目录时，macOS 可能询问访问权限。",
                    actionTitle: "开始扫描",
                    action: { scanner.refresh() }
                )
            } else if scanner.nodes.isEmpty {
                WorkspaceEmptyState(
                    symbol: "square.grid.3x3",
                    title: scanner.wasCancelled ? "扫描已取消" : "没有可显示的内容",
                    detail: scanner.wasCancelled
                        ? "点右上角重新扫描当前文件夹"
                        : "只统计可读文件大小，隐藏项与符号链接已跳过",
                    actionTitle: "扫描当前文件夹",
                    action: { scanner.refresh() }
                )
            } else {
                treemap
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var scanningState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("正在统计 \(scanner.currentName) 的体积")
                .font(.system(size: 12.5, weight: .medium))
            Text("已检查 \(scanner.scannedCount) 个文件 · 只读取文件大小")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button("取消扫描") {
                scanner.cancel()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(24)
    }

    private var treemap: some View {
        GeometryReader { proxy in
            let nodes = scanner.nodes.filter { $0.size > 0 }
            let rects = SquarifiedTreemap.rects(
                values: nodes.map(weight),
                in: CGRect(origin: .zero, size: proxy.size).insetBy(dx: 8, dy: 8)
            )
            ZStack(alignment: .topLeading) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    if index < rects.count {
                        let rect = rects[index]
                        if rect.width >= 5, rect.height >= 5 {
                            WorkspaceMatrixTile(
                                node: node,
                                rect: rect.insetBy(dx: 1.5, dy: 1.5),
                                index: index,
                                isSelected: selectedURL == node.url,
                                onHover: { hovering in
                                    if hovering {
                                        hoveredURL = node.url
                                    } else if hoveredURL == node.url {
                                        hoveredURL = nil
                                    }
                                },
                                onTap: {
                                    selectedURL = node.url
                                    if node.isDirectory {
                                        scanner.open(node)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let node = focusedNode {
                HStack(spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: node.url.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Text(node.isDirectory ? "文件夹" : "文件")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("体积")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(ByteFormatting.size(node.size))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                Text(node.url.path)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer(minLength: 0)

                VStack(spacing: 7) {
                    inspectorButton(
                        title: node.isDirectory ? "展开此文件夹" : "在 Finder 中显示",
                        symbol: node.isDirectory ? "arrow.down.right.and.arrow.up.left" : "finder"
                    ) {
                        if node.isDirectory {
                            scanner.open(node)
                        } else {
                            reveal(node.url)
                        }
                    }
                    inspectorButton(title: "复制路径", symbol: "doc.on.doc") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(node.url.path, forType: .string)
                        showToast(.success, "已复制路径")
                    }
                    if !node.isDirectory {
                        inspectorButton(title: "移到废纸篓", symbol: "trash", destructive: true) {
                            trash(node)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 22))
                        .foregroundStyle(IslandTheme.accent)
                    Text("点选一个区块")
                        .font(.system(size: 12.5, weight: .medium))
                    Text("点击文件夹继续钻取；点击文件在此查看路径与操作。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            SettingsSurface(tint: IslandTheme.accent.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func inspectorButton(
        title: String,
        symbol: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(destructive ? IslandTheme.error : Color.primary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                (destructive ? IslandTheme.error : Color.primary).opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        (destructive ? IslandTheme.error : Color.primary).opacity(0.08),
                        lineWidth: 0.75
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func weight(_ node: FileMatrixScanner.Node) -> Double {
        pow(log(Double(max(node.size, 1)) + 1), 3)
    }

    private func trash(_ node: FileMatrixScanner.Node) {
        let confirmed = SystemPanels.confirmDestructive(
            title: "移到废纸篓？",
            message: "\(node.name)（\(ByteFormatting.size(node.size))）\n\(node.url.deletingLastPathComponent().path)\n\n文件会移到废纸篓，可在 Finder 中恢复。",
            confirmTitle: "移到废纸篓"
        )
        guard confirmed else {
            return
        }
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            scanner.remove(node.url)
            if selectedURL == node.url {
                selectedURL = nil
            }
            if hoveredURL == node.url {
                hoveredURL = nil
            }
            showToast(.success, "已移到废纸篓：\(node.name)")
        } catch {
            showToast(.error, "无法移到废纸篓：\(error.localizedDescription)")
        }
    }
}

private struct WorkspaceMatrixTile: View {
    let node: FileMatrixScanner.Node
    let rect: CGRect
    let index: Int
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var showsName: Bool {
        rect.width >= 56 && rect.height >= 28
    }

    private var showsSize: Bool {
        rect.width >= 64 && rect.height >= 48
    }

    private var showsIcon: Bool {
        rect.width >= 70 && rect.height >= 66
    }

    private var tint: Color {
        let opacities: [Double] = [0.26, 0.15, 0.21, 0.11, 0.30, 0.17]
        let base = index.isMultiple(of: 3) ? IslandTheme.accentDeep : IslandTheme.accent
        return base.opacity(opacities[index % opacities.count])
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(IslandTheme.tileFill)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint)
                VStack(alignment: .leading, spacing: 2) {
                    if showsIcon {
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(IslandTheme.textSecondary.opacity(0.9))
                    }
                    Spacer(minLength: 0)
                    if showsName {
                        Text(node.name)
                            .font(.system(size: rect.height > 90 ? 12 : 10.5, weight: .semibold))
                            .foregroundStyle(IslandTheme.textPrimary)
                            .lineLimit(rect.height > 90 ? 2 : 1)
                            .truncationMode(.middle)
                    }
                    if showsSize {
                        Text(ByteFormatting.size(node.size))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(IslandTheme.textSecondary)
                    }
                }
                .padding(7)
            }
            .frame(width: rect.width, height: rect.height)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isSelected || isHovered
                            ? IslandTheme.accent.opacity(0.95)
                            : IslandTheme.contrast(0.06),
                        lineWidth: isSelected || isHovered ? 1.2 : 0.5
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .position(x: rect.midX, y: rect.midY)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                isHovered = hovering
            }
            onHover(hovering)
        }
        .help("\(node.url.path)\n\(ByteFormatting.size(node.size))")
        .contextMenu {
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
        }
    }
}

private struct WorkspaceLargeFilesPage: View {
    @ObservedObject var scanner: LargeFileScanner
    let reveal: (URL) -> Void
    let showToast: (WorkspaceToast.Kind, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("主目录中 50 MB 以上的文件")
                        .font(.system(size: 12, weight: .medium))
                    Text("只读取文件大小，跳过 Library、隐藏文件与 App 包；首次扫描时 macOS 可能询问文件夹访问权限。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                if scanner.isScanning {
                    Text("已检查 \(scanner.scannedCount) 个文件")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Button(scanner.isScanning ? "取消" : (scanner.lastScanDate == nil ? "扫描主目录" : "重新扫描")) {
                    scanner.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 22)

            list
                .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var list: some View {
        if scanner.isScanning, scanner.files.isEmpty {
            WorkspaceEmptyState(
                symbol: "magnifyingglass",
                title: "正在扫描主目录…",
                detail: "已检查 \(scanner.scannedCount) 个文件",
                actionTitle: "取消扫描",
                action: { scanner.cancel() }
            )
            .background {
                SettingsSurface(tint: IslandTheme.accent.opacity(0.035))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if scanner.files.isEmpty {
            WorkspaceEmptyState(
                symbol: "doc",
                title: scanner.lastScanDate == nil ? "还没有扫描" : "没有找到大文件",
                detail: scanner.lastScanDate == nil
                    ? "扫描后按体积列出主目录中最大的文件"
                    : "可重新扫描；扫描范围仅限主目录",
                actionTitle: scanner.lastScanDate == nil ? "开始扫描" : "重新扫描",
                action: { scanner.toggle() }
            )
            .background {
                SettingsSurface(tint: IslandTheme.accent.opacity(0.035))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(scanner.files) { file in
                        row(file)
                    }
                }
                .padding(10)
            }
            .scrollIndicators(.hidden)
            .background {
                SettingsSurface(tint: IslandTheme.accent.opacity(0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func row(_ file: LargeFileScanner.LargeFile) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.url.deletingLastPathComponent().path)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text(ByteFormatting.size(file.size))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                reveal(file.url)
            } label: {
                Image(systemName: "finder")
                    .font(.system(size: 11))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help("在 Finder 中显示")
            Button {
                trash(file)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(IslandTheme.error)
            .help("移到废纸篓")
        }
        .padding(.horizontal, 9)
        .frame(height: 44)
        .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contextMenu {
            Button("在 Finder 中显示") { reveal(file.url) }
            Button("移到废纸篓", role: .destructive) { trash(file) }
        }
    }

    private func trash(_ file: LargeFileScanner.LargeFile) {
        let confirmed = SystemPanels.confirmDestructive(
            title: "移到废纸篓？",
            message: "\(file.url.lastPathComponent)（\(ByteFormatting.size(file.size))）\n\(file.url.deletingLastPathComponent().path)\n\n文件会移到废纸篓，可在 Finder 中恢复。",
            confirmTitle: "移到废纸篓"
        )
        guard confirmed else {
            return
        }
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            scanner.remove(file.url)
            showToast(.success, "已移到废纸篓：\(file.url.lastPathComponent)")
        } catch {
            showToast(.error, "无法移到废纸篓：\(error.localizedDescription)")
        }
    }
}
