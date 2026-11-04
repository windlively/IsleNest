import AppKit
import SwiftUI

enum CaptureHUDKind {
    case scrolling
    case recording
    case saved
}

@MainActor
final class CaptureHUDModel: ObservableObject {
    @Published var kind: CaptureHUDKind = .scrolling
    @Published var title = ""
    @Published var detail = ""
    @Published var actionTitle = "完成"
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
}

@MainActor
final class CaptureHUDController {
    private let model = CaptureHUDModel()
    private var panel: NSPanel?
    private var framePanel: NSPanel?

    func show(
        on screen: NSScreen,
        kind: CaptureHUDKind,
        title: String,
        detail: String,
        actionTitle: String,
        highlightRect: CGRect? = nil,
        highlightColor: NSColor = .systemBlue,
        onFinish: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss()

        model.kind = kind
        model.title = title
        model.detail = detail
        model.actionTitle = actionTitle
        model.onFinish = onFinish
        model.onCancel = onCancel

        let size = NSSize(width: 392, height: 82)
        let panel = CaptureHUDPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .none
        panel.contentView = CaptureHUDHostingView(rootView: CaptureHUDView(model: model))

        let top = screen.visibleFrame.maxY - 14
        let x = screen.frame.midX - size.width / 2
        panel.setFrame(
            NSRect(x: x, y: top - size.height, width: size.width, height: size.height),
            display: false
        )
        self.panel = panel

        if let highlightRect, !highlightRect.isEmpty {
            presentFrame(highlightRect, on: screen, color: highlightColor)
        }

        // Stay non-key so the app underneath keeps focus and scrolling keeps working.
        panel.orderFrontRegardless()
    }

    private func presentFrame(_ rect: CGRect, on screen: NSScreen, color: NSColor) {
        // Draw the frame just outside the captured rect; ScreenCaptureKit records
        // the exact region, so a border drawn inside would end up in the video.
        let outer = rect.insetBy(dx: -4, dy: -4)
        let global = NSRect(
            x: screen.frame.minX + outer.minX,
            y: screen.frame.minY + screen.frame.height - outer.maxY,
            width: outer.width,
            height: outer.height
        )
        let panel = CaptureHUDPanel(
            contentRect: global,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .none
        panel.contentView = CaptureRegionFrameView(
            frame: NSRect(origin: .zero, size: global.size),
            color: color
        )
        framePanel = panel
        panel.orderFrontRegardless()
    }

    func update(detail: String) {
        model.detail = detail
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        framePanel?.orderOut(nil)
        framePanel = nil
        model.onFinish = nil
        model.onCancel = nil
    }
}

private final class CaptureHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class CaptureRegionFrameView: NSView {
    private let color: NSColor

    init(frame frameRect: NSRect, color: NSColor) {
        self.color = color
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        color.withAlphaComponent(0.95).setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()

        NSColor.white.withAlphaComponent(0.35).setStroke()
        let inner = NSBezierPath(rect: bounds.insetBy(dx: 3, dy: 3))
        inner.lineWidth = 1
        inner.stroke()
    }
}

private final class CaptureHUDHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct CaptureHUDView: View {
    @ObservedObject var model: CaptureHUDModel

    var body: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text(model.detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: { model.onFinish?() }) {
                Text(model.actionTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(IslandTheme.accentInk)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(IslandTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: { model.onCancel?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(IslandTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help("取消")
        }
        .padding(.horizontal, 14)
        .frame(width: 372, height: 62)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: 0x0B0F12, opacity: 0.96))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(IslandTheme.accent.opacity(0.12), lineWidth: 1)
                    .padding(0.5)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        .padding(10)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var icon: some View {
        switch model.kind {
        case .scrolling:
            Image(systemName: "scroll.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(IslandTheme.accent)
                .frame(width: 32, height: 32)
                .background(IslandTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .recording:
            HStack(spacing: 5) {
                Circle()
                    .fill(IslandTheme.error)
                    .frame(width: 7, height: 7)
                    .shadow(color: IslandTheme.error.opacity(0.6), radius: 4)
                Image(systemName: "record.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IslandTheme.error)
            }
            .frame(width: 38, height: 32)
            .background(IslandTheme.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(IslandTheme.accent)
                .frame(width: 38, height: 32)
                .background(IslandTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
