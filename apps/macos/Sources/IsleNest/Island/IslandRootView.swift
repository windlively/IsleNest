import IsleNestCore
import SwiftUI

struct IslandRootView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var scene: IslandScene
    @ObservedObject var config: ConfigStore
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var recentFiles: RecentFilesStore
    let actions: IslandActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var surfaceExpanded = false

    private var wantsExpanded: Bool {
        model.isExpanded && scene.isActive
    }

    private var surfaceSize: CGSize {
        if isFused || surfaceExpanded {
            // Fused styles keep the expanded envelope so every state change animates only the clipped shape.
            return scene.expandedSize
        }
        if scene.isPeeking {
            return scene.peekSize
        }
        return scene.collapsedSize
    }

    private var style: ResolvedIslandStyle {
        scene.style
    }

    private var isFused: Bool {
        style == .notch || style == .menuBar
    }

    private var isFusedCollapsed: Bool {
        isFused && !surfaceExpanded
    }

    private var isPillCollapsed: Bool {
        style == .menuBar && !surfaceExpanded
    }

    private var surfaceShadowRadius: CGFloat {
        if isPillCollapsed {
            return 6
        }
        return isFusedCollapsed ? 0 : (isFused ? 8 : 10)
    }

    private var surfaceShadowOpacity: Double {
        if isPillCollapsed {
            return 0.28
        }
        return isFusedCollapsed ? 0 : (isFused ? 0.24 : 0.32)
    }

    private var surfaceShape: AnyShape {
        IslandTheme.islandShape(style: style, expanded: surfaceExpanded)
    }

    private var notchBarWidth: CGFloat {
        if surfaceExpanded {
            return IslandTheme.expandedSize.width
        }
        if scene.isPeeking {
            return scene.peekSize.width
        }
        return scene.collapsedSize.width
    }

    private var pillVerticalInset: CGFloat {
        guard isPillCollapsed else {
            return 0
        }
        let available = scene.collapsedSize.height - IslandTheme.menuBarPillMinHeight
        return min(IslandTheme.menuBarPillVerticalInset, max(0, available / 2))
    }

    private var barBodyHeight: CGFloat {
        if surfaceExpanded {
            return scene.expandedSize.height
        }
        if isPillCollapsed {
            return max(
                IslandTheme.menuBarPillMinHeight,
                scene.collapsedSize.height - pillVerticalInset * 2
            )
        }
        return scene.collapsedSize.height
    }

    private var notchShape: IslandBarShape {
        let capsuleRadius = barBodyHeight / 2
        return IslandBarShape(
            barWidth: notchBarWidth,
            bodyHeight: barBodyHeight,
            topInset: pillVerticalInset,
            topRadius: isPillCollapsed ? capsuleRadius : 0,
            bottomRadius: surfaceExpanded
                ? IslandTheme.expandedCornerRadius
                : (isPillCollapsed ? capsuleRadius : IslandTheme.notchBarCornerRadius)
        )
    }

    private var notchAnimation: Animation? {
        IslandTheme.morphAnimation(reduceMotion: reduceMotion)
    }

    private var rimGradient: LinearGradient {
        LinearGradient(
            colors: [IslandTheme.contrast(isFused ? 0.13 : 0.2),
                     IslandTheme.contrast(0.055), IslandTheme.contrast(0.085)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            surface
            Spacer(minLength: 0)
        }
        .padding(.top, style == .floating ? IslandTheme.shadowInset : 0)
        .padding(.horizontal, IslandTheme.shadowInset)
        .padding(.bottom, IslandTheme.shadowInset)
        .frame(
            width: scene.windowSize.width,
            height: scene.windowSize.height,
            alignment: .top
        )
        .background(Color.clear)
        .onAppear {
            surfaceExpanded = wantsExpanded
        }
        .onChange(of: wantsExpanded) { _, newValue in
            withAnimation(IslandTheme.morphAnimation(reduceMotion: reduceMotion)) {
                surfaceExpanded = newValue
            }
        }
    }

    private var surface: some View {
        shapedSurface
            .shadow(
                color: .black.opacity(surfaceShadowOpacity),
                radius: surfaceShadowRadius,
                x: 0,
                y: isPillCollapsed ? 2 : (isFusedCollapsed ? 0 : 4)
            )
            .overlay {
                if isFused {
                    if surfaceExpanded {
                        notchShape
                            .stroke(rimGradient, lineWidth: 1)
                            .frame(width: surfaceSize.width, height: surfaceSize.height)
                            .animation(notchAnimation, value: scene.isPeeking)
                            .animation(notchAnimation, value: surfaceExpanded)
                    }
                } else {
                    surfaceShape
                        .stroke(rimGradient, lineWidth: 1)
                }
            }
            .contentShape(isFused ? AnyShape(notchShape) : AnyShape(Rectangle()))
            .dropDestination(for: URL.self) { urls, _ in
                actions.pinURLs(urls)
            } isTargeted: { targeted in
                actions.dragTargetChanged(targeted)
            }
            .animation(.easeOut(duration: 0.18), value: model.notice?.id)
    }

    @ViewBuilder
    private var shapedSurface: some View {
        if isFused {
            surfaceBody
                .clipShape(notchShape)
                .animation(notchAnimation, value: scene.isPeeking)
                .animation(notchAnimation, value: surfaceExpanded)
        } else {
            surfaceBody
                .clipShape(surfaceShape)
        }
    }

    private var surfaceBody: some View {
        ZStack(alignment: .top) {
            surfaceBackground

            Group {
                if let result = model.result {
                    ResultView(result: result, model: model, actions: actions)
                } else if model.showsShelf {
                    ShelfView(config: config, model: model, actions: actions)
                } else if model.showsRecentFiles {
                    RecentFilesView(store: recentFiles, model: model, actions: actions)
                } else if model.showsPomodoro {
                    PomodoroView(timer: timer, model: model, actions: actions)
                } else {
                    HomeView(config: config, model: model, timer: timer, actions: actions)
                }
            }
            .frame(
                width: IslandTheme.expandedSize.width,
                height: IslandTheme.expandedSize.height,
                alignment: .top
            )
            .padding(.top, scene.contentTopInset)
            .frame(width: surfaceSize.width, height: surfaceSize.height, alignment: .top)
            .opacity(surfaceExpanded ? 1 : 0)
            .allowsHitTesting(surfaceExpanded)
            .accessibilityHidden(!surfaceExpanded)
            .animation(
                .easeOut(duration: surfaceExpanded ? 0.12 : 0.08),
                value: surfaceExpanded
            )

            Group {
                if style == .menuBar {
                    PillCollapsedView(
                        actions: actions,
                        timer: timer,
                        isPeeking: scene.isPeeking
                    )
                    .frame(
                        width: notchBarWidth,
                        height: scene.collapsedSize.height
                    )
                } else if isFused {
                    NotchCollapsedView(
                        actions: actions,
                        timer: timer,
                        notchWidth: scene.notchWidth,
                        idleBarWidth: scene.collapsedSize.width,
                        peekBarWidth: scene.peekSize.width,
                        isPeeking: scene.isPeeking
                    )
                    .frame(
                        width: notchBarWidth,
                        height: scene.collapsedSize.height
                    )
                } else {
                    CollapsedIslandView(actions: actions, timer: timer)
                        .frame(
                            width: scene.collapsedSize.width,
                            height: scene.collapsedSize.height
                        )
                }
            }
            .opacity(surfaceExpanded ? 0 : 1)
            .allowsHitTesting(!surfaceExpanded)
            .accessibilityHidden(surfaceExpanded)
            .animation(.easeOut(duration: 0.08), value: surfaceExpanded)

            if surfaceExpanded, model.isDropTargeted {
                VStack(spacing: 14) {
                    Image(systemName: "pin.fill").font(.system(size: 28, weight: .medium))
                    Text("松手，放入栖岛").font(.system(size: 18, weight: .semibold))
                    Text("文件夹、应用与网页固定；其他文件暂存")
                        .font(.system(size: 12)).foregroundStyle(IslandTheme.textSecondary)
                }
                .foregroundStyle(IslandTheme.accent)
                .frame(width: IslandTheme.expandedSize.width - 32,
                       height: IslandTheme.expandedSize.height - 32)
                .background(IslandTheme.dropFill, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(IslandTheme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 5])))
                .padding(.top, scene.contentTopInset + 16)
                .allowsHitTesting(false)
                .zIndex(3)
            }

            if surfaceExpanded, let notice = model.notice {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    NoticeOverlay(notice: notice, dismiss: actions.dismissNotice)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
                .frame(
                    width: IslandTheme.expandedSize.width,
                    height: IslandTheme.expandedSize.height,
                    alignment: .top
                )
                .padding(.top, scene.contentTopInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .frame(width: surfaceSize.width, height: surfaceSize.height)
    }

    private var surfaceBackground: some View {
        ZStack {
            IslandTheme.surfaceBase
            IslandDiffuseBackground(palette: config.settings.theme.palette)
                .opacity(surfaceExpanded ? 1 : (style == .notch ? 0 : 0.6))
        }
    }
}
