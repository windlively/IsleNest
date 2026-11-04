import SwiftUI

struct PomodoroView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var model: IslandModel
    let actions: IslandActions

    private var phaseColor: Color {
        timer.phase == .focus
            ? IslandTheme.accent
            : Color.adaptive(light: 0x2F8F72, dark: 0x86D8B9)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            Spacer(minLength: 2)
            ring
            sessionBadge
            controls
            Spacer(minLength: 4)
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(phaseColor)
                .frame(width: 32, height: 32)
                .background(
                    phaseColor.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("番茄钟")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text("25 分钟专注 · 5 分钟休息")
                    .font(.system(size: 11))
                    .foregroundStyle(IslandTheme.textTertiary)
            }

            Spacer(minLength: 0)

            HeaderIconButton(
                symbol: "chevron.left",
                label: "返回工具",
                focusID: .pomodoroBack,
                model: model,
                action: actions.togglePomodoro
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

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(IslandTheme.contrast(0.06), lineWidth: 12)

            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    phaseColor.opacity(timer.isRunning ? 0.95 : 0.7),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.45), value: timer.progress)

            VStack(spacing: 7) {
                Text(timer.phase.title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(phaseColor)

                Text(timer.timeText)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(IslandTheme.textPrimary)
                    .contentTransition(.numericText(countsDown: true))

                Text(timer.phase.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(IslandTheme.textTertiary)
            }
        }
        .frame(width: 206, height: 206)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timer.phase.title)计时，剩余 \(timer.timeText)")
        .accessibilityValue(timer.isRunning ? "计时中" : "已暂停")
    }

    private var sessionBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 10, weight: .medium))
            Text(timer.sessionText)
                .monospacedDigit()
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(IslandTheme.textTertiary)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(IslandTheme.tileFill, in: Capsule())
    }

    private var controls: some View {
        HStack(spacing: 8) {
            PomodoroActionButton(
                symbol: timer.isRunning ? "pause.fill" : "play.fill",
                title: timer.startButtonTitle,
                primary: true,
                focusID: .pomodoroToggle,
                model: model,
                action: { timer.toggle() }
            )
            PomodoroActionButton(
                symbol: "arrow.counterclockwise",
                title: "重置",
                primary: false,
                focusID: .pomodoroReset,
                model: model,
                action: { timer.reset() }
            )
            PomodoroActionButton(
                symbol: "forward.end",
                title: timer.phase == .focus ? "休息" : "专注",
                primary: false,
                focusID: .pomodoroSkip,
                model: model,
                action: { timer.skip() }
            )
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(IslandTheme.divider).frame(height: 0.5)
            HStack(spacing: 6) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 10))
                Text("收起后继续计时，完成时提示")
                Spacer(minLength: 0)
                Text("esc").font(.system(size: 9.5, design: .monospaced))
                Text("返回")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(IslandTheme.textTertiary)
        }
    }
}

private struct PomodoroActionButton: View {
    let symbol: String
    let title: String
    let primary: Bool
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
            .frame(height: 40)
            .islandGlass(
                primary ? .prominent : .control,
                cornerRadius: 11,
                active: isHovered
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .islandFocusRing(isSelected, cornerRadius: 11)
        .accessibilityLabel(title)
    }
}
