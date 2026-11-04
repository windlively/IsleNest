import AppKit
import ScreenCaptureKit
import SwiftUI

struct WindowCandidate: Identifiable {
    let id: CGWindowID
    let window: SCWindow
    let title: String
    let appName: String
    let appIcon: NSImage?
    let aspectRatio: CGFloat
    var thumbnail: NSImage?
}

@MainActor
final class WindowPickerModel: ObservableObject {
    @Published var candidates: [WindowCandidate]

    init(candidates: [WindowCandidate]) {
        self.candidates = candidates
    }

    func setThumbnail(_ image: NSImage, for id: CGWindowID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else {
            return
        }
        candidates[index].thumbnail = image
    }
}

@MainActor
final class WindowPickerController {
    private var panel: WindowPickerPanel?
    private var model: WindowPickerModel?
    private var continuation: CheckedContinuation<SCWindow?, Never>?
    private var thumbnailTask: Task<Void, Never>?

    var isPresenting: Bool {
        panel != nil
    }

    func pick(
        from windows: [SCWindow],
        on screen: NSScreen,
        service: CaptureService
    ) async -> SCWindow? {
        await withCheckedContinuation { continuation in
            present(windows: windows, on: screen, service: service, continuation: continuation)
        }
    }

    func cancel() {
        finish(nil)
    }

    private func present(
        windows: [SCWindow],
        on screen: NSScreen,
        service: CaptureService,
        continuation: CheckedContinuation<SCWindow?, Never>
    ) {
        guard panel == nil else {
            continuation.resume(returning: nil)
            return
        }

        let candidates = windows.map { window -> WindowCandidate in
            let application = window.owningApplication
            let appName = application?.applicationName ?? "未知应用"
            let title = (window.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let processID = application?.processID
            let icon = processID.flatMap { NSRunningApplication(processIdentifier: $0)?.icon }
            let aspect = window.frame.height > 0 ? window.frame.width / window.frame.height : 1
            return WindowCandidate(
                id: window.windowID,
                window: window,
                title: title.isEmpty ? appName : title,
                appName: appName,
                appIcon: icon,
                aspectRatio: aspect,
                thumbnail: nil
            )
        }

        let model = WindowPickerModel(candidates: candidates)
        let panel = WindowPickerPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        let view = WindowPickerView(
            model: model,
            screenSize: screen.frame.size,
            onPick: { [weak self] window in
                self?.finish(window)
            },
            onCancel: { [weak self] in
                self?.finish(nil)
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.onEscape = { [weak self] in
            self?.finish(nil)
        }

        self.panel = panel
        self.model = model
        self.continuation = continuation

        panel.makeKeyAndOrderFront(nil)
        startThumbnailLoading(windows: windows, model: model, service: service)
    }

    private func startThumbnailLoading(
        windows: [SCWindow],
        model: WindowPickerModel,
        service: CaptureService
    ) {
        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak model] in
            for window in windows {
                guard !Task.isCancelled, let model else {
                    return
                }
                if let thumbnail = await service.thumbnail(for: window) {
                    model.setThumbnail(thumbnail, for: window.windowID)
                }
            }
        }
    }

    private func finish(_ window: SCWindow?) {
        guard let panel, let continuation else {
            return
        }
        thumbnailTask?.cancel()
        thumbnailTask = nil
        self.panel = nil
        self.model = nil
        self.continuation = nil
        panel.onEscape = nil
        panel.orderOut(nil)
        continuation.resume(returning: window)
    }
}

final class WindowPickerPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            onEscape?()
            return
        }
        super.sendEvent(event)
    }
}

struct WindowPickerView: View {
    @ObservedObject var model: WindowPickerModel
    let screenSize: CGSize
    let onPick: (SCWindow) -> Void
    let onCancel: () -> Void

    @State private var isCloseHovered = false

    private var containerWidth: CGFloat {
        min(max(screenSize.width * 0.78, 640), 1040)
    }

    private var containerHeight: CGFloat {
        min(max(screenSize.height * 0.7, 440), 760)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.46)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                header
                Divider()
                    .overlay(Color.white.opacity(0.08))

                if model.candidates.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(IslandTheme.textTertiary)
                        Text("没有可截取的窗口")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(IslandTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(model.candidates) { candidate in
                                WindowCandidateCard(candidate: candidate) {
                                    onPick(candidate.window)
                                }
                            }
                        }
                        .padding(18)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(width: containerWidth, height: containerHeight)
            .islandGlass(.panel, cornerRadius: 20, interactive: false)
            .shadow(color: .black.opacity(0.55), radius: 34, x: 0, y: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(IslandTheme.accent.opacity(0.12))
                Image(systemName: "macwindow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IslandTheme.accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("选择要截取的窗口")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text("\(model.candidates.count) 个可截取窗口 · 点击选择 · Esc 取消")
                    .font(.system(size: 10.5))
                    .foregroundStyle(IslandTheme.textTertiary)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(IslandTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .islandGlass(.control, cornerRadius: 8, active: isCloseHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isCloseHovered = hovering
                }
            }
            .accessibilityLabel("取消窗口截屏")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct WindowCandidateCard: View {
    let candidate: WindowCandidate
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.38))

                    if let thumbnail = candidate.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(6)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(IslandTheme.textTertiary)
                    }
                }
                .frame(height: 146)
                .padding(.horizontal, 8)
                .padding(.top, 8)

                HStack(spacing: 8) {
                    if let icon = candidate.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 17, height: 17)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(IslandTheme.textTertiary)
                            .frame(width: 17, height: 17)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(candidate.title)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(IslandTheme.textPrimary)
                            .lineLimit(1)
                        Text(candidate.appName)
                            .font(.system(size: 9.5))
                            .foregroundStyle(IslandTheme.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
            }
            .islandGlass(.tile, cornerRadius: 14, active: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("\(candidate.appName)，\(candidate.title)")
        .accessibilityHint("截取这个窗口")
    }
}
