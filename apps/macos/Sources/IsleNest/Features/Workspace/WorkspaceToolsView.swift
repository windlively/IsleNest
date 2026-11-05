import IsleNestCore
import AppKit
import SwiftUI

struct WorkspaceToolsView: View {
    let config: ConfigStore
    let services: WorkspaceServices
    let actions: WorkspaceActions
    let openSection: (WorkspaceSection) -> Void
    let openSettings: (SettingsTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WorkspacePageHeader(
                    title: "工具",
                    subtitle: "快捷动作与本地小工具",
                    symbol: "wrench.and.screwdriver"
                ) {
                    EmptyView()
                }

                WorkspaceCard(title: "快捷动作") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 9), count: 4),
                        spacing: 9
                    ) {
                        WorkspaceActionTile(
                            symbol: "eyedropper",
                            title: "屏幕取色",
                            detail: "复制 HEX / RGB",
                            accent: true
                        ) {
                            actions.sampleColor()
                        }
                        WorkspaceActionTile(
                            symbol: "viewfinder",
                            title: "区域截屏",
                            detail: "框选后标注",
                            accent: true
                        ) {
                            actions.capture(.region)
                        }
                        WorkspaceActionTile(
                            symbol: "record.circle",
                            title: "区域录屏",
                            detail: "H.264 MP4"
                        ) {
                            actions.recordRegion()
                        }
                        WorkspaceActionTile(
                            symbol: "folder",
                            title: "打开下载",
                            detail: "Downloads"
                        ) {
                            NSWorkspace.shared.open(
                                FileManager.default.homeDirectoryForCurrentUser
                                    .appendingPathComponent("Downloads")
                            )
                        }
                        WorkspaceActionTile(
                            symbol: "desktopcomputer",
                            title: "打开桌面",
                            detail: "Desktop"
                        ) {
                            NSWorkspace.shared.open(
                                FileManager.default.homeDirectoryForCurrentUser
                                    .appendingPathComponent("Desktop")
                            )
                        }
                        WorkspaceActionTile(
                            symbol: "house",
                            title: "个人目录",
                            detail: "Home"
                        ) {
                            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
                        }
                        WorkspaceActionTile(
                            symbol: "folder.badge.gearshape",
                            title: "固定文件夹",
                            detail: "\(config.folders.count) 个"
                        ) {
                            openSettings(.folders)
                        }
                        WorkspaceActionTile(
                            symbol: "square.grid.2x2",
                            title: "快捷启动",
                            detail: "\(config.launchItems.count) 个"
                        ) {
                            openSettings(.launch)
                        }
                    }
                }

                WorkspaceCard(title: "即将接入") {
                    VStack(alignment: .leading, spacing: 9) {
                        toolRow(
                            symbol: "cup.and.saucer",
                            title: "防休眠 / 演示模式",
                            detail: "保持屏幕唤醒，支持定时"
                        )
                        toolRow(
                            symbol: "qrcode",
                            title: "二维码与计算",
                            detail: "从剪贴板生成二维码、快速换算"
                        )
                        toolRow(
                            symbol: "play.rectangle",
                            title: "媒体控制",
                            detail: "播放 / 暂停与当前曲目"
                        )
                        toolRow(
                            symbol: "battery.75",
                            title: "电池与热状态",
                            detail: "循环次数、健康度与机身热状态"
                        )
                    }
                }

                Text("工具页会随着后续批次继续补齐；当前截屏、录屏、取色与文件夹管理已可用。")
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
    }

    private func toolRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("后续")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Color.primary.opacity(0.05), in: Capsule())
        }
        .padding(.vertical, 3)
    }
}
