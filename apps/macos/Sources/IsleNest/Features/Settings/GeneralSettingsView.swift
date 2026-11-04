import IsleNestCore
import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var loginModel: LoginItemModel

    @State private var hasShortcut = false
    @State private var showResetConfirm = false
    @State private var screens: [NSScreen] = NSScreen.screens

    private var configurableScreens: [NSScreen] {
        guard config.settings.style != .floating else {
            return []
        }
        return screens
    }

    var body: some View {
        SettingsPage(title: "通用", subtitle: "外观、岛体行为与启动方式", symbol: "gearshape") {
            SettingsCard(
                title: "主题",
                footer: "\(config.settings.theme.displayName) · \(config.settings.theme.themeDescription)。每套主题都提供深浅两版：深色版顶部纯黑、渐变铺满面板；浅色版贴近系统菜单栏。刘海屏岛体始终使用深色版，避免浅色横条与物理刘海拼贴；深浅外观作用于无刘海屏与设置窗口，选择“跟随系统”会随 macOS 外观自动切换。"
            ) {
                SettingsRow {
                    ThemePickerView(selection: $config.settings.theme)
                }

                SettingsDivider()

                SettingsPickerRow(
                    title: "深浅外观",
                    detail: "跟随系统时，设置窗口与无刘海屏岛体随 macOS 深浅模式切换；刘海屏岛体保持深色"
                ) {
                    Picker("深浅外观", selection: $config.settings.appearance) {
                        Text("跟随系统").tag(IslandAppearanceMode.system)
                        Text("浅色").tag(IslandAppearanceMode.light)
                        Text("深色").tag(IslandAppearanceMode.dark)
                    }
                    .pickerStyle(.menu)
                }
            }

            SettingsCard(
                title: "岛体",
                footer: "每台显示器的菜单栏都会显示栖岛；“自动”在刘海屏与刘海同高融合，其他屏幕显示菜单栏悬浮药丸；浮动胶囊显示在菜单栏下方。浮动位置只对胶囊形态生效。"
            ) {
                SettingsPickerRow(title: "形态") {
                    Picker("形态", selection: $config.settings.style) {
                        Text("自动（推荐）").tag(IslandStyle.automatic)
                        Text("贴顶融合").tag(IslandStyle.notch)
                        Text("浮动胶囊").tag(IslandStyle.floating)
                    }
                    .pickerStyle(.menu)
                }

                SettingsDivider()

                SettingsPickerRow(title: "展开方式") {
                    Picker("展开方式", selection: $config.settings.trigger) {
                        Text("点击展开").tag(IslandTrigger.click)
                        Text("悬停展开").tag(IslandTrigger.hover)
                    }
                    .pickerStyle(.menu)
                }

                SettingsDivider()

                SettingsRow {
                    Text("刘海横条或菜单栏药丸上，悬停会先横向展开预览，点击展开全部工具。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if config.settings.trigger == .hover {
                    SettingsDivider()
                    SettingsRow {
                        Text("鼠标停留约 0.35 秒展开，离开面板约 0.5 秒收起。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsDivider()

                SettingsPickerRow(title: "浮动位置") {
                    Picker("浮动位置", selection: $config.settings.floatingAnchor) {
                        Text("靠左").tag(FloatingAnchor.left)
                        Text("居中").tag(FloatingAnchor.center)
                        Text("靠右").tag(FloatingAnchor.right)
                    }
                    .pickerStyle(.menu)
                }
            }

            SettingsCard(
                title: "岛体宽度",
                footer: "每台显示器的收起宽度可单独调整；内建刘海屏保持略宽于实体刘海，以便完整显示两侧入口。悬停预览仍向两侧展开，展开面板尺寸保持不变。"
            ) {
                if configurableScreens.isEmpty {
                    SettingsRow {
                        Text(
                            config.settings.style == .floating
                                ? "浮动胶囊形态使用统一尺寸，不使用单屏宽度。"
                                : "未检测到可用显示器。"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(
                        Array(configurableScreens.enumerated()),
                        id: \.element.configurationKey
                    ) { index, screen in
                        screenWidthRow(screen)

                        if index < configurableScreens.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }

            SettingsCard(
                title: "唤起",
                footer: "录制时会提示已知的系统或菜单快捷键冲突；无法检测所有第三方应用的占用。"
            ) {
                SettingsRow {
                    KeyboardShortcuts.Recorder(
                        "唤出 / 收起栖岛",
                        name: .toggleIsland
                    ) { shortcut in
                        hasShortcut = shortcut != nil
                    }
                }

                if !hasShortcut {
                    SettingsDivider()
                    SettingsRow {
                        Text("尚未设置全局快捷键。仍可点击屏幕顶部的小岛唤出。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SettingsCard(
                title: "启动",
                footer: "仅在用户主动开启后注册登录项；系统侧禁用时会显示真实状态。"
            ) {
                SettingsRow {
                    Toggle(
                        "登录时自动启动",
                        isOn: Binding(
                            get: { loginModel.isEnabled },
                            set: { loginModel.setEnabled($0) }
                        )
                    )
                    .toggleStyle(.switch)
                }

                if let detail = loginModel.statusDetail {
                    SettingsDivider()
                    SettingsRow {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let error = loginModel.errorMessage {
                    SettingsDivider()
                    SettingsRow {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SettingsCard(footer: "恢复默认不会删除已固定的文件夹和快捷启动项。") {
                SettingsRow {
                    Button("恢复默认设置…", role: .destructive) {
                        showResetConfirm = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            loginModel.refresh()
            hasShortcut = KeyboardShortcuts.getShortcut(for: .toggleIsland) != nil
            screens = NSScreen.screens
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginModel.refresh()
            hasShortcut = KeyboardShortcuts.getShortcut(for: .toggleIsland) != nil
            screens = NSScreen.screens
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
        .alert("恢复默认设置？", isPresented: $showResetConfirm) {
            Button("恢复默认", role: .destructive) {
                config.resetSettings()
                KeyboardShortcuts.resetAll()
                hasShortcut = false
                loginModel.refresh()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会把主题、深浅外观、形态、展开方式、单屏宽度、截屏输出和快捷键恢复为默认；不会删除已收藏的内容。")
        }
    }

    @ViewBuilder
    private func screenWidthRow(_ screen: NSScreen) -> some View {
        let metrics = DisplayCoordinator.notchMetrics(for: screen)

        SettingsRow {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(screen.displayName)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(Int(width(for: screen).rounded())) pt")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: widthBinding(for: screen),
                    in: widthRange(for: screen),
                    step: 4
                )

                if metrics.hasNotch {
                    Text("最小 \(Int(notchMinimumWidth(for: screen).rounded())) pt，保证两侧入口圆点完整")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func notchMinimumWidth(for screen: NSScreen) -> Double {
        let metrics = DisplayCoordinator.notchMetrics(for: screen)
        let notchWidth = max(metrics.notchWidth, IslandTheme.menuBarWidthRange.lowerBound)
        return Double(notchWidth + IslandTheme.notchMinimumSideExtension * 2)
    }

    private func widthRange(for screen: NSScreen) -> ClosedRange<Double> {
        let metrics = DisplayCoordinator.notchMetrics(for: screen)
        let lower = metrics.hasNotch
            ? notchMinimumWidth(for: screen)
            : Double(IslandTheme.menuBarWidthRange.lowerBound)
        let upper = max(lower, Double(IslandTheme.menuBarWidthRange.upperBound))
        return lower...upper
    }

    private func defaultWidth(for screen: NSScreen) -> Double {
        let metrics = DisplayCoordinator.notchMetrics(for: screen)
        guard metrics.hasNotch else {
            return Double(IslandTheme.menuBarIdleWidth)
        }
        let notchWidth = max(metrics.notchWidth, IslandTheme.menuBarWidthRange.lowerBound)
        return Double(notchWidth + IslandTheme.notchIdleSideExtension * 2)
    }

    private func width(for screen: NSScreen) -> Double {
        let range = widthRange(for: screen)
        let value = config.settings.displayIslandWidths[screen.configurationKey]
            ?? defaultWidth(for: screen)
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private func widthBinding(for screen: NSScreen) -> Binding<Double> {
        Binding(
            get: { width(for: screen) },
            set: { config.settings.displayIslandWidths[screen.configurationKey] = $0 }
        )
    }
}
