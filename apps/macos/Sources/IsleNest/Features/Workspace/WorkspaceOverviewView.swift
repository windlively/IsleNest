import IsleNestCore
import AppKit
import SwiftUI

struct WorkspaceOverviewView: View {
    @ObservedObject var config: ConfigStore
    let services: WorkspaceServices
    let actions: WorkspaceActions
    let openSection: (WorkspaceSection) -> Void
    let showToast: (WorkspaceToast.Kind, String) -> Void

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 · EEEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WorkspacePageHeader(
                    title: "概览",
                    subtitle: "\(dateText) · 全部数据仅在本机",
                    symbol: "square.grid.2x2"
                ) {
                    HStack(spacing: 8) {
                        Button {
                            actions.capture(.region)
                        } label: {
                            Label("区域截屏", systemImage: "viewfinder")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Button("打开文件管理") {
                            openSection(.files)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    OverviewSystemCard(monitor: services.systemMonitor) {
                        openSection(.system)
                    }
                    OverviewFocusCard(timer: services.pomodoro)
                        .frame(width: 256)
                }

                WorkspaceCard(title: "快捷动作") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 9), count: 6),
                        spacing: 9
                    ) {
                        WorkspaceActionTile(
                            symbol: "viewfinder",
                            title: "区域截屏",
                            detail: "⌘1",
                            accent: true
                        ) {
                            actions.capture(.region)
                        }
                        WorkspaceActionTile(
                            symbol: "record.circle",
                            title: "区域录屏",
                            detail: "⌘5"
                        ) {
                            actions.recordRegion()
                        }
                        WorkspaceActionTile(
                            symbol: "eyedropper",
                            title: "屏幕取色",
                            detail: "HEX / RGB"
                        ) {
                            actions.sampleColor()
                        }
                        WorkspaceActionTile(
                            symbol: "arrow.down.circle",
                            title: "打开下载",
                            detail: "Downloads"
                        ) {
                            NSWorkspace.shared.open(
                                FileManager.default.homeDirectoryForCurrentUser
                                    .appendingPathComponent("Downloads")
                            )
                        }
                        WorkspaceActionTile(
                            symbol: "folder",
                            title: "文件管理",
                            detail: "矩阵与清理"
                        ) {
                            openSection(.files)
                        }
                        WorkspaceActionTile(
                            symbol: "gauge",
                            title: "系统详情",
                            detail: "CPU / 内存 / 磁盘"
                        ) {
                            openSection(.system)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    OverviewRecentFilesCard(
                        store: services.recentFiles,
                        reveal: actions.revealFile,
                        showToast: showToast
                    )
                    .frame(maxWidth: .infinity)

                    OverviewSpaceCard(monitor: services.systemMonitor) {
                        openSection(.files)
                    }
                    .frame(width: 300)
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 10))
                    Text("剪贴板、截图与文件索引只在本机处理，不上传、不写入第三方服务。")
                    Spacer(minLength: 0)
                    Text("栖岛 \(version) · 开发预览")
                        .monospacedDigit()
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .onAppear {
            services.systemMonitor.start()
            services.recentFiles.load()
        }
        .onDisappear {
            services.systemMonitor.stop()
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

private struct OverviewSystemCard: View {
    @ObservedObject var monitor: SystemMonitor
    let openDetails: () -> Void

    var body: some View {
        WorkspaceCard(title: "系统状态", trailing: "1.5 秒刷新") {
            HStack(alignment: .top, spacing: 18) {
                metric(
                    title: "CPU",
                    value: "\(Int((monitor.cpuUsage * 100).rounded()))%",
                    detail: "当前占用",
                    progress: monitor.cpuUsage
                )
                divider
                metric(
                    title: "内存",
                    value: ByteFormatting.memory(monitor.memoryUsed),
                    detail: "共 \(ByteFormatting.memory(monitor.memoryTotal))",
                    progress: monitor.memoryUsage
                )
                divider
                metric(
                    title: "磁盘",
                    value: "\(Int((monitor.diskUsage * 100).rounded()))%",
                    detail: "可用 \(ByteFormatting.size(Int64(monitor.diskFree)))",
                    progress: monitor.diskUsage
                )
                divider
                VStack(alignment: .leading, spacing: 6) {
                    Text("网络")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .semibold))
                        Text(ByteFormatting.speed(monitor.downloadBytesPerSecond))
                            .monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .semibold))
                        Text(ByteFormatting.speed(monitor.uploadBytesPerSecond))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: openDetails) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(IslandTheme.accent)
                        .frame(width: 26, height: 26)
                        .background(
                            IslandTheme.accent.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .help("打开系统详情")
            }
        }
    }

    private func metric(title: String, value: String, detail: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(IslandTheme.accent.opacity(0.75))
                        .frame(width: max(4, proxy.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 3)
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(width: 0.5, height: 68)
    }
}

private struct OverviewFocusCard: View {
    @ObservedObject var timer: PomodoroTimer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WorkspaceCard(title: "番茄钟", trailing: timer.phase.title) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.07), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            IslandTheme.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(timer.timeText)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(timer.isRunning ? "进行中" : (timer.isActive ? "已暂停" : "准备开始"))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 104, height: 104)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: timer.progress)

                Text(timer.sessionText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                HStack(spacing: 7) {
                    Button(timer.startButtonTitle) {
                        timer.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("重置") {
                        timer.reset()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("跳过") {
                        timer.skip()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct OverviewSpaceCard: View {
    @ObservedObject var monitor: SystemMonitor
    let openFiles: () -> Void

    var body: some View {
        WorkspaceCard(title: "空间") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(IslandTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(
                            IslandTheme.accent.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monitor.diskName)
                            .font(.system(size: 12.5, weight: .medium))
                        Text(
                            "可用 \(ByteFormatting.size(Int64(monitor.diskFree))) · 共 \(ByteFormatting.size(Int64(monitor.diskTotal)))"
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(Int((monitor.diskUsage * 100).rounded()))%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(IslandTheme.accent)
                }

                Button(action: openFiles) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.3x3")
                        Text("打开文件矩阵与大文件")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IslandTheme.accent)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(
                        IslandTheme.accent.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct OverviewRecentFilesCard: View {
    @ObservedObject var store: RecentFilesStore
    let reveal: (URL) -> Void
    let showToast: (WorkspaceToast.Kind, String) -> Void

    var body: some View {
        WorkspaceCard(title: "最近文件", trailing: store.files.isEmpty ? nil : "\(store.files.count) 项") {
            VStack(spacing: 0) {
                if store.isLoading, store.files.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在读取最近使用记录…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 62)
                } else if store.files.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundStyle(IslandTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("还没有最近文件")
                                .font(.system(size: 11.5, weight: .medium))
                            Text("打开文件后会出现在这里")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button("刷新") {
                            store.load(force: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(height: 62)
                } else {
                    ForEach(Array(store.files.prefix(5).enumerated()), id: \.element.id) { index, file in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, 34)
                        }
                        row(file)
                    }
                }
            }
        }
    }

    private func row(_ file: RecentFilesStore.RecentFile) -> some View {
        Button {
            guard FileManager.default.fileExists(atPath: file.url.path) else {
                showToast(.info, "文件已不存在：\(file.name)")
                store.load(force: true)
                return
            }
            NSWorkspace.shared.open(file.url)
        } label: {
            HStack(spacing: 9) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(file.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(file.folderName)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("在 Finder 中显示") {
                reveal(file.url)
            }
            Button("复制路径") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
                showToast(.success, "已复制路径")
            }
        }
        .help(file.url.path)
    }
}
