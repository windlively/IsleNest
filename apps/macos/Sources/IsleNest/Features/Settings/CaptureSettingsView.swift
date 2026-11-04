import IsleNestCore
import KeyboardShortcuts
import SwiftUI

struct CaptureSettingsView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var permissionModel: ScreenPermissionModel

    var body: some View {
        SettingsPage(title: "截屏", subtitle: "捕获方式、录屏权限与保存规则", symbol: "camera.viewfinder") {
            SettingsCard(title: "截屏结果") {
                SettingsPickerRow(title: "完成后") {
                    Picker("完成后", selection: $config.settings.captureOutputMode) {
                        Text("显示结果，稍后复制或保存").tag(CaptureOutputMode.preview)
                        Text("自动复制到剪贴板").tag(CaptureOutputMode.autoCopy)
                    }
                    .pickerStyle(.menu)
                }

                SettingsDivider()

                SettingsRow {
                    Text(
                        config.settings.captureOutputMode == .preview
                            ? "捕获后显示结果面板，由你选择复制或保存。"
                            : "捕获后自动写入剪贴板，同时保留结果面板用于保存。"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            SettingsCard(
                title: "全局快捷键",
                footer: "未录制时不占用任何系统快捷键。录制时会提示已知的系统或菜单快捷键冲突；无法检测所有第三方应用的占用。"
            ) {
                SettingsRow {
                    KeyboardShortcuts.Recorder("区域截屏", name: .captureRegion)
                }
                SettingsDivider()
                SettingsRow {
                    KeyboardShortcuts.Recorder("窗口截屏", name: .captureWindow)
                }
                SettingsDivider()
                SettingsRow {
                    KeyboardShortcuts.Recorder("全屏截屏", name: .captureDisplay)
                }
                SettingsDivider()
                SettingsRow {
                    KeyboardShortcuts.Recorder("滚动截屏", name: .captureScrolling)
                }
                SettingsDivider()
                SettingsRow {
                    KeyboardShortcuts.Recorder("区域录屏", name: .recordRegion)
                }
                SettingsDivider()
                SettingsRow {
                    KeyboardShortcuts.Recorder("屏幕取色", name: .sampleColor)
                }
            }

            SettingsCard(
                title: "保存位置",
                footer: "截图保存会默认打开这里，开启下方选项后直接写入；录屏会直接保存到指定文件夹。目录不可用时自动回退到系统默认位置。"
            ) {
                locationRow(
                    title: "截图保存位置",
                    path: config.settings.screenshotDirectoryPath,
                    defaultText: "系统默认位置",
                    chooseMessage: "选择截图的默认保存文件夹"
                ) { path in
                    config.settings.screenshotDirectoryPath = path
                }

                SettingsDivider()

                locationRow(
                    title: "录屏保存位置",
                    path: config.settings.recordingDirectoryPath,
                    defaultText: "影片",
                    chooseMessage: "选择录屏的保存文件夹"
                ) { path in
                    config.settings.recordingDirectoryPath = path
                }

                SettingsDivider()

                SettingsRow {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("保存时不再询问")
                                .font(.system(size: 13))
                            Text(
                                config.settings.screenshotDirectoryPath == nil
                                    ? "需先选择截图保存位置；未设置时仍会弹出保存对话框。"
                                    : "点击保存后直接写入截图目录，不再弹出保存对话框。"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Toggle("", isOn: $config.settings.screenshotSaveWithoutPrompt)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(config.settings.screenshotDirectoryPath == nil)
                    }
                }
            }

            SettingsCard(
                title: "屏幕录制权限",
                footer: "栖岛只在截屏或录屏时读取屏幕内容。权限被撤回后，其他功能仍可继续使用。"
            ) {
                SettingsRow {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: permissionModel.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(permissionModel.isGranted ? .green : .orange)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(permissionModel.isGranted ? "已获得屏幕录制权限" : "尚未获得屏幕录制权限")
                                .font(.system(size: 13, weight: .medium))
                            Text("首次截屏时由 macOS 请求授权。系统可能在授权后要求重新启动栖岛。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SettingsDivider()

                SettingsRow {
                    HStack(spacing: 10) {
                        if !permissionModel.isGranted {
                            Button("请求权限") {
                                permissionModel.request()
                            }
                        }
                        Button("打开系统设置") {
                            permissionModel.openSystemSettings()
                        }
                        if !permissionModel.isGranted {
                            Button("重新启动栖岛") {
                                permissionModel.relaunch()
                            }
                        }
                    }
                }

                if let note = permissionModel.note {
                    SettingsDivider()
                    SettingsRow {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SettingsCard(title: "保存与隐私") {
                privacyLine("截图保存默认打开设置中的目录；开启「保存时不再询问」后直接写入。录屏直接保存到设置中的目录，重名文件自动生成新名称，不覆盖已有文件。")
                SettingsDivider()
                privacyLine("截取前会隐藏岛体，并在捕获过滤器中排除栖岛自身窗口。")
                SettingsDivider()
                privacyLine("滚动截屏沿用截屏结果；区域录屏以 MP4 保存，可在上方单独设置保存位置。")
                SettingsDivider()
                privacyLine("不会扫描其他截图文件，也不会后台读取剪贴板历史。")
            }
        }
        .onAppear {
            permissionModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionModel.refresh()
        }
    }

    private func privacyLine(_ text: String) -> some View {
        SettingsRow {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(IslandTheme.accent.opacity(0.8))
                    .frame(width: 15)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    private func locationRow(
        title: String,
        path: String?,
        defaultText: String,
        chooseMessage: String,
        update: @escaping (String?) -> Void
    ) -> some View {
        SettingsRow {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                    Text(displayPath(path, fallback: defaultText))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let path, !directoryAvailable(path) {
                        Text("目录不可用，保存时将回退到默认位置")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer(minLength: 8)

                if path != nil {
                    Button("恢复默认") {
                        update(nil)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11.5))
                }

                Button("选择…") {
                    if let url = SystemPanels.chooseDirectory(message: chooseMessage) {
                        update(url.standardizedFileURL.path)
                    }
                }
                .font(.system(size: 11.5))
            }
        }
    }

    private func displayPath(_ path: String?, fallback: String) -> String {
        guard let path, !path.isEmpty else {
            return fallback
        }
        let displayName = FileManager.default.displayName(atPath: path)
        return "\(displayName) — \((path as NSString).abbreviatingWithTildeInPath)"
    }

    private func directoryAvailable(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
