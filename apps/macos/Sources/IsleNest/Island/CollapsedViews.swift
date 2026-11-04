import SwiftUI

struct NotchCollapsedView: View {
    let actions: IslandActions
    @ObservedObject var timer: PomodoroTimer
    let notchWidth: CGFloat
    let idleBarWidth: CGFloat
    let peekBarWidth: CGFloat
    let isPeeking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var earCenter: CGFloat {
        let barWidth = isPeeking ? peekBarWidth : idleBarWidth
        return (barWidth + notchWidth) / 4
    }

    private var morph: Animation? {
        IslandTheme.morphAnimation(reduceMotion: reduceMotion)
    }

    var body: some View {
        Button(action: actions.toggle) {
            ZStack {
                leftContent
                    .offset(x: -earCenter)
                    .animation(morph, value: isPeeking)

                rightContent
                    .offset(x: earCenter)
                    .animation(morph, value: isPeeking)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .help(timer.isActive ? "栖岛 · \(timer.phase.title) \(timer.timeText)" : "栖岛")
        .accessibilityLabel(timer.isActive ? "栖岛入口，\(timer.phase.title)剩余 \(timer.timeText)" : "栖岛入口")
        .accessibilityHint("悬停预览，点击展开常用工具")
    }

    @ViewBuilder
    private var leftContent: some View {
        if isPeeking {
            HStack(spacing: 4) {
                IslandTheme.brandMark(size: 14)

                Text("栖岛")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(IslandTheme.textPrimary)
                    .lineLimit(1)
            }
            .transition(.opacity)
        } else if timer.isActive {
            timerGlyph
                .transition(.opacity)
        } else {
            idleDot
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var rightContent: some View {
        if isPeeking {
            HStack(spacing: 3) {
                if timer.isActive {
                    timerText(size: 10.5)
                } else {
                    Text("点击展开")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(IslandTheme.textSecondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(IslandTheme.accent.opacity(0.9))
            }
            .transition(.opacity)
        } else if timer.isActive {
            timerText(size: 9.5)
                .transition(.opacity)
        } else {
            idleDot
                .transition(.opacity)
        }
    }

    private var timerGlyph: some View {
        Image(systemName: timer.phase == .focus ? "timer" : "cup.and.saucer")
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(IslandTheme.accent.opacity(0.95))
            .shadow(color: IslandTheme.accent.opacity(0.25), radius: 2)
    }

    private func timerText(size: CGFloat) -> some View {
        Text(timer.timeText)
            .font(.system(size: size, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(IslandTheme.accent)
            .lineLimit(1)
    }

    private var idleDot: some View {
        Circle()
            .fill(IslandTheme.accent.opacity(isHovered ? 0.95 : 0.7))
            .frame(width: 3.5, height: 3.5)
            .shadow(color: IslandTheme.accent.opacity(0.45), radius: 3)
    }
}

struct PillCollapsedView: View {
    let actions: IslandActions
    @ObservedObject var timer: PomodoroTimer
    let isPeeking: Bool

    @State private var isHovered = false

    var body: some View {
        Button(action: actions.toggle) {
            HStack(spacing: 7) {
                IslandTheme.brandMark(size: 14)

                Text("栖岛")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(IslandTheme.textPrimary)
                    .lineLimit(1)

                if timer.isActive {
                    Rectangle()
                        .fill(IslandTheme.divider)
                        .frame(width: 1, height: 11)

                    HStack(spacing: 4) {
                        Image(systemName: timer.phase == .focus ? "timer" : "cup.and.saucer")
                            .font(.system(size: 9, weight: .medium))
                        Text(timer.timeText)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(IslandTheme.accent)
                    .transition(.opacity)
                }

                if isPeeking {
                    HStack(spacing: 7) {
                        if !timer.isActive {
                            Rectangle()
                                .fill(IslandTheme.divider)
                                .frame(width: 1, height: 11)

                            Text("点击展开")
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(IslandTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(IslandTheme.accent.opacity(0.9))
                    }
                    .transition(.opacity)
                } else {
                    Circle()
                        .fill(IslandTheme.accent.opacity(isHovered ? 0.95 : 0.7))
                        .frame(width: 3.5, height: 3.5)
                        .shadow(color: IslandTheme.accent.opacity(0.45), radius: 3)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .help(timer.isActive ? "栖岛 · \(timer.phase.title) \(timer.timeText)" : "栖岛")
        .accessibilityLabel(timer.isActive ? "栖岛入口，\(timer.phase.title)剩余 \(timer.timeText)" : "栖岛入口")
        .accessibilityHint("悬停预览，点击展开常用工具")
        .animation(.easeOut(duration: 0.16), value: isPeeking)
    }
}

struct CollapsedIslandView: View {
    let actions: IslandActions
    @ObservedObject var timer: PomodoroTimer

    @State private var isHovered = false

    var body: some View {
        Button(action: actions.toggle) {
            HStack(spacing: 7) {
                IslandTheme.brandMark(size: 15)

                if timer.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: timer.phase == .focus ? "timer" : "cup.and.saucer")
                            .font(.system(size: 9, weight: .medium))
                        Text(timer.timeText)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(IslandTheme.accent)
                    .transition(.opacity)
                } else {
                    Text("栖岛")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(IslandTheme.textPrimary)
                }

                Circle()
                    .fill(IslandTheme.accent)
                    .frame(width: 4.5, height: 4.5)
                    .opacity(isHovered ? 1 : 0.78)
                    .shadow(color: IslandTheme.accent.opacity(isHovered ? 0.55 : 0.25), radius: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .help(timer.isActive ? "栖岛 · \(timer.phase.title) \(timer.timeText)" : "栖岛")
        .accessibilityLabel(timer.isActive ? "栖岛入口，\(timer.phase.title)剩余 \(timer.timeText)" : "栖岛入口")
        .accessibilityHint("展开常用工具")
    }
}
