import SwiftUI

struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        SettingsPage(title: "关于", subtitle: "栖岛 Islenest", symbol: "info.circle") {
            SettingsCard {
                VStack(spacing: 12) {
                    IslandTheme.brandMark(size: 64)

                    VStack(spacing: 4) {
                        Text("栖岛")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                        Text("ISLENEST")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(4)
                            .foregroundStyle(.secondary)
                    }

                    Text("常用功能，轻触即达。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Text("驻留屏幕顶部、按需展开的 macOS 效率工具栏。把截屏、常用文件夹、快捷启动与文件暂存集中在一个小岛里，收起后保持安静。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }

            SettingsCard(title: "应用信息") {
                infoRow("版本", "\(version)（\(build)） · 开发预览")
                SettingsDivider()
                infoRow("运行要求", "macOS 14 及以上")
                SettingsDivider()
                infoRow("技术栈", "SwiftUI · 原生")
                SettingsDivider()
                infoRow("开源依赖", "KeyboardShortcuts（MIT）")
            }
        }
    }

    private func infoRow(_ title: String, _ detail: String) -> some View {
        SettingsRow {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 12.5))
                Spacer(minLength: 12)
                Text(detail)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
