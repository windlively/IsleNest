import SwiftUI

struct ResultView: View {
    let result: ScreenshotResult
    @ObservedObject var model: IslandModel
    let actions: IslandActions

    private var isBusy: Bool {
        model.isResultBusy
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            preview
                .padding(.top, 12)

            metaRow
                .padding(.top, 9)

            HStack(spacing: 8) {
                ResultActionButton(
                    symbol: "doc.on.doc",
                    title: "复制图片  ⌘C",
                    primary: true,
                    disabled: isBusy,
                    focusID: .resultCopy,
                    model: model,
                    action: actions.copyResult
                )
                ResultActionButton(
                    symbol: "square.and.arrow.down",
                    title: "保存 PNG  ⌘S",
                    primary: false,
                    disabled: isBusy,
                    focusID: .resultSave,
                    model: model,
                    action: actions.saveResult
                )
            }
            .padding(.top, 10)

            HStack(spacing: 8) {
                ResultActionButton(
                    symbol: "text.viewfinder", title: "取字  ⌘T", primary: false,
                    disabled: isBusy, focusID: .resultOCR, model: model,
                    action: actions.recognizeResultText
                )
                ResultActionButton(
                    symbol: "arrow.clockwise", title: "再截一张  ⌘R", primary: false,
                    disabled: isBusy, focusID: .resultRetake, model: model, action: actions.retakeResult
                )
            }
            .padding(.top, 8)

            if let savedURL = result.savedURL {
                savedRow(savedURL)
                    .padding(.top, 8)
            }

            Spacer(minLength: 6)

            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("截屏结果")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text("\(result.kind.title) · \(result.sourceTitle ?? "屏幕")")
                    .font(.system(size: 11))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(IslandTheme.accent)
            }

            HeaderIconButton(
                symbol: "square.and.arrow.up",
                label: "分享截图",
                focusID: .resultShare,
                model: model,
                action: actions.shareResult
            )
            HeaderIconButton(
                symbol: "xmark",
                label: "关闭结果，返回工具",
                focusID: .resultClose,
                model: model,
                action: actions.closeResult
            )
        }
        .frame(height: 34)
    }

    private var preview: some View {
        ZStack {
            Image(nsImage: result.preview)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(6)
        }
        .frame(height: 228)
        .islandGlass(.panel, cornerRadius: 14, interactive: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("截屏预览，\(result.sizeDescription)")
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "aspectratio")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(IslandTheme.textTertiary)
            Text(result.sizeDescription)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(IslandTheme.textSecondary)

            Text("·")
                .foregroundStyle(IslandTheme.textTertiary)

            Text(result.capturedAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11))
                .foregroundStyle(IslandTheme.textTertiary)

            Spacer(minLength: 0)
        }
        .frame(height: 14)
        .accessibilityElement(children: .combine)
    }

    private func savedRow(_ savedURL: URL) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(IslandTheme.accent)

            Text(savedURL.lastPathComponent)
                .font(.system(size: 11))
                .foregroundStyle(IslandTheme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            RevealButton(model: model, action: actions.revealResult)
        }
        .frame(height: 20)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: result.savedURL == nil ? "info.circle" : "checkmark.circle")
                .font(.system(size: 9))
            Text(result.savedURL == nil ? "未保存的结果在关闭后清除" : "已保存，可继续复制或关闭")
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("Esc 关闭并收起")
        }
        .font(.system(size: 11))
        .foregroundStyle(IslandTheme.textTertiary.opacity(0.85))
        .accessibilityHidden(true)
    }
}

private struct ResultActionButton: View {
    let symbol: String
    let title: String
    let primary: Bool
    let disabled: Bool
    let focusID: IslandFocusID
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == focusID
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(primary ? IslandTheme.accentInk : IslandTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .islandGlass(
                primary ? .prominent : .control,
                cornerRadius: 10,
                active: isHovered
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected && !primary, cornerRadius: 10)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    primary && isSelected ? Color.white.opacity(0.85) : Color.clear,
                    lineWidth: 1.5
                )
        }
        .accessibilityLabel(title)
    }
}

private struct RevealButton: View {
    @ObservedObject var model: IslandModel
    let action: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        model.keyboardFocusVisible && model.selectedFocus == .resultReveal
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 9, weight: .semibold))
                Text("在 Finder 中显示")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovered ? IslandTheme.accent : IslandTheme.textSecondary)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .islandGlass(.control, cornerRadius: 6, active: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 6)
        .accessibilityLabel("在 Finder 中显示已保存图片")
    }
}
