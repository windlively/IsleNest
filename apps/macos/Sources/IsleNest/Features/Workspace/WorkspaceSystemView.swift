import IsleNestCore
import SwiftUI

struct WorkspaceSystemView: View {
    private let services: WorkspaceServices
    private let openSection: (WorkspaceSection) -> Void
    @ObservedObject private var monitor: SystemMonitor

    init(services: WorkspaceServices, openSection: @escaping (WorkspaceSection) -> Void) {
        self.services = services
        self.openSection = openSection
        self._monitor = ObservedObject(wrappedValue: services.systemMonitor)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WorkspacePageHeader(
                    title: "系统",
                    subtitle: "实时资源 · 只在查看时采样",
                    symbol: "gauge"
                ) {
                    Text("1.5 秒刷新")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    WorkspaceMetricCard(
                        symbol: "cpu",
                        title: "CPU",
                        value: "\(Int((monitor.cpuUsage * 100).rounded()))%",
                        detail: "当前总占用",
                        progress: monitor.cpuUsage
                    )
                    WorkspaceMetricCard(
                        symbol: "memorychip",
                        title: "内存",
                        value: ByteFormatting.memory(monitor.memoryUsed),
                        detail: "共 \(ByteFormatting.memory(monitor.memoryTotal))",
                        progress: monitor.memoryUsage
                    )
                    WorkspaceMetricCard(
                        symbol: "internaldrive",
                        title: "磁盘",
                        value: "\(Int((monitor.diskUsage * 100).rounded()))%",
                        detail: "可用 \(ByteFormatting.size(Int64(monitor.diskFree)))",
                        progress: monitor.diskUsage
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    WorkspaceCard(title: "网络", trailing: "实时") {
                        HStack(spacing: 26) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundStyle(.tertiary)
                                Text(ByteFormatting.speed(monitor.downloadBytesPerSecond))
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text("下载")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                Text(ByteFormatting.speed(monitor.uploadBytesPerSecond))
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text("上传")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    WorkspaceCard(title: monitor.diskName) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(Int((monitor.diskUsage * 100).rounded()))%")
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(IslandTheme.accent)
                                Text("已用")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Text("可用 \(ByteFormatting.size(Int64(monitor.diskFree)))")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.07))
                                    Capsule()
                                        .fill(IslandTheme.accent.opacity(0.8))
                                        .frame(width: max(4, proxy.size.width * monitor.diskUsage))
                                }
                            }
                            .frame(height: 6)
                            Button {
                                openSection(.files)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.grid.3x3")
                                    Text("打开文件矩阵")
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(IslandTheme.accent)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(
                                    IslandTheme.accent.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 320)
                }

                WorkspaceCard(title: "说明") {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12))
                            .foregroundStyle(IslandTheme.accent)
                        Text("系统数据通过本机 API 读取，只在当前页面可见时采样；不申请额外权限，也不会上传。磁盘容量与 Activity Monitor 的统计口径可能略有差异。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .onAppear {
            monitor.start()
        }
        .onDisappear {
            monitor.stop()
        }
    }
}
