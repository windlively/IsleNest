import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let onFinish: () -> Void
    private var window: NSWindow?
    private var didFinish = false

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    func show() {
        didFinish = false
        if window == nil {
            buildWindow()
        }
        guard let window else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func buildWindow() {
        let view = OnboardingView { [weak self] in
            self?.finish()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "欢迎使用栖岛"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedWhite: 0.035, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.setContentSize(NSSize(width: 560, height: 520))
        window.center()
        window.delegate = self
        self.window = window
    }

    private func finish() {
        guard !didFinish else {
            return
        }
        didFinish = true
        window?.orderOut(nil)
        window?.close()
        onFinish()
    }

    func windowWillClose(_ notification: Notification) {
        guard !didFinish else {
            return
        }
        didFinish = true
        onFinish()
        DispatchQueue.main.async {
            NSApp.deactivate()
        }
    }
}

private struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var hasShortcut = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x15181C), Color(hex: 0x07080A)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [IslandTheme.accent.opacity(0.09), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 22)

                IslandTheme.brandMark(size: 56)

                Text("栖岛")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(IslandTheme.textPrimary)
                    .padding(.top, 12)

                Text("ISLENEST")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(4)
                    .foregroundStyle(IslandTheme.textTertiary)
                    .padding(.top, 2)

                Text("常用功能，轻触即达。")
                    .font(.system(size: 13))
                    .foregroundStyle(IslandTheme.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    feature(
                        symbol: "viewfinder",
                        title: "截屏闭环",
                        detail: "区域、窗口、全屏，复制或保存"
                    )
                    feature(
                        symbol: "folder",
                        title: "常用文件夹",
                        detail: "固定工作目录，一次点击打开"
                    )
                    feature(
                        symbol: "square.grid.2x2",
                        title: "快捷启动",
                        detail: "应用与网页，展开即启动"
                    )
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 8) {
                    Text("设置全局快捷键")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(IslandTheme.textSecondary)

                    KeyboardShortcuts.Recorder(
                        "唤出 / 收起栖岛",
                        name: .toggleIsland
                    ) { shortcut in
                        hasShortcut = shortcut != nil
                    }

                    Text(
                        hasShortcut
                            ? "已设置。点击屏幕顶部的小岛也可以随时唤出。"
                            : "可选，之后可以随时在设置中更改。"
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(IslandTheme.textTertiary)
                }
                .padding(14)
                .islandGlass(.panel, cornerRadius: 14, interactive: false)
                .padding(.top, 18)

                Spacer(minLength: 16)

                Button(action: onFinish) {
                    Text("开始使用")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x08201B))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .islandGlass(.prominent, cornerRadius: 11)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("开始使用栖岛")

                Text("点击屏幕顶部的刘海或小岛唤出；Esc 收起")
                    .font(.system(size: 10))
                    .foregroundStyle(IslandTheme.textTertiary)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 44)
            .padding(.bottom, 18)
        }
        .frame(width: 560, height: 520)
        .preferredColorScheme(.dark)
    }

    private func feature(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(IslandTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(IslandTheme.accent.opacity(0.09))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(IslandTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(IslandTheme.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .islandGlass(.tile, cornerRadius: 11, interactive: false)
    }
}
