import AppKit
import IsleNestCore
import UniformTypeIdentifiers
import os

@MainActor
final class CaptureResultOverlayController {
    var onClose: (() -> Void)?
    var onPin: ((CGImage) -> Void)?

    private let image: CGImage
    private let screen: NSScreen
    private let imageRect: CGRect
    private let contentSize: CGSize?
    private let sourceTitle: String?
    private let autoCopy: Bool
    private let suggestedBaseName: String
    private let defaultDirectory: URL?
    private let saveWithoutPrompt: Bool

    private var panel: CaptureResultOverlayPanel?
    private var overlayView: CaptureResultOverlayView?
    private var isOperating = false
    private var sharePicker: NSSharingServicePicker?

    var isPresenting: Bool {
        panel != nil
    }

    init(
        image: CGImage,
        screen: NSScreen,
        imageRect: CGRect,
        contentSize: CGSize? = nil,
        sourceTitle: String?,
        autoCopy: Bool,
        defaultDirectory: URL? = nil,
        saveWithoutPrompt: Bool = false,
        capturedAt: Date = Date()
    ) {
        self.image = image
        self.screen = screen
        self.imageRect = imageRect
        self.contentSize = contentSize
        self.sourceTitle = sourceTitle
        self.autoCopy = autoCopy
        self.defaultDirectory = defaultDirectory
        self.saveWithoutPrompt = saveWithoutPrompt
        self.suggestedBaseName = FilenameAllocator.screenshotBaseName(date: capturedAt)
    }

    func present() {
        guard panel == nil else {
            return
        }

        let panel = CaptureResultOverlayPanel(
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

        let view = CaptureResultOverlayView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            image: image,
            imageRect: imageRect,
            contentSize: contentSize
        )
        view.autoresizingMask = [.width, .height]
        view.onCancel = { [weak self] in
            self?.dismiss()
        }
        view.onCopy = { [weak self] rendered in
            self?.copy(rendered, closeAfter: true)
        }
        view.onSave = { [weak self] rendered in
            self?.save(rendered)
        }
        view.onShare = { [weak self] rendered in
            self?.share(rendered)
        }
        view.onOCR = { [weak self] base in
            self?.recognize(base)
        }
        view.onPin = { [weak self] rendered in
            guard let self else {
                return
            }
            let handler = self.onPin
            self.onPin = nil
            self.dismiss()
            handler?(rendered)
        }

        panel.contentView = view
        self.panel = panel
        self.overlayView = view

        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
        NSCursor.arrow.set()

        Logger.capture.info(
            "Result overlay presented title=\(self.sourceTitle ?? "-", privacy: .public) autoCopy=\(self.autoCopy, privacy: .public)"
        )

        if autoCopy {
            copy(image, closeAfter: false, isAutomatic: true)
        }

        if view.isScrollable {
            view.showToast("滚动查看完整长图", autoHideAfter: 2.4)
        }
    }

    func dismiss() {
        tearDown(notify: true)
    }

    func cancelForTermination() {
        tearDown(notify: false)
    }

    private func tearDown(notify: Bool) {
        guard let panel else {
            return
        }
        self.panel = nil
        self.overlayView = nil
        panel.orderOut(nil)
        NSCursor.arrow.set()

        let handler = onClose
        onClose = nil
        if notify {
            handler?()
        }
    }

    // MARK: - Copy

    private func copy(_ image: CGImage, closeAfter: Bool, isAutomatic: Bool = false) {
        guard !isOperating, let view = overlayView else {
            return
        }
        isOperating = true
        view.setBusy(true)

        Task { @MainActor [weak self] in
            let payload = await Task.detached(priority: .userInitiated) {
                (image.pngData(), image.tiffData())
            }.value

            guard let self else {
                return
            }
            self.isOperating = false
            self.overlayView?.setBusy(false)

            guard let png = payload.0 else {
                self.overlayView?.showToast(CaptureError.encodeFailed.localizedDescription)
                return
            }

            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            if let tiff = payload.1 {
                item.setData(tiff, forType: .tiff)
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.writeObjects([item]) else {
                self.overlayView?.showToast("复制失败，请重试")
                return
            }

            Logger.capture.info("Overlay screenshot copied auto=\(isAutomatic, privacy: .public)")
            if closeAfter {
                self.dismiss()
            } else {
                self.overlayView?.showToast(
                    isAutomatic ? "已自动复制到剪贴板" : "已复制到剪贴板"
                )
            }
        }
    }

    // MARK: - Save

    private func save(_ image: CGImage) {
        guard !isOperating, let view = overlayView else {
            return
        }

        if saveWithoutPrompt, let directory = defaultDirectory {
            saveDirectly(image, to: directory)
            return
        }

        isOperating = true
        view.setBusy(true)

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = "\(suggestedBaseName).png"
        savePanel.message = "选择栖岛截图的保存位置"
        if let defaultDirectory {
            savePanel.directoryURL = defaultDirectory
        }

        panel?.level = .floating
        NSApp.activate(ignoringOtherApps: true)

        savePanel.begin { [weak self] response in
            guard let self else {
                return
            }
            Task { @MainActor in
                self.panel?.level = .screenSaver
                if let panel = self.panel, let view = self.overlayView {
                    panel.makeKeyAndOrderFront(nil)
                    panel.makeFirstResponder(view)
                }

                guard response == .OK, let chosenURL = savePanel.url else {
                    self.isOperating = false
                    self.overlayView?.setBusy(false)
                    return
                }

                let targetURL = FilenameAllocator.uniqueURL(for: chosenURL)
                let data = await Task.detached(priority: .userInitiated) {
                    image.pngData()
                }.value

                self.isOperating = false
                self.overlayView?.setBusy(false)

                guard let data else {
                    self.overlayView?.showToast(CaptureError.encodeFailed.localizedDescription)
                    return
                }

                do {
                    try data.write(to: targetURL, options: .atomic)
                } catch {
                    Logger.capture.error(
                        "Overlay screenshot write failed: \(error.localizedDescription, privacy: .public)"
                    )
                    self.overlayView?.showToast("保存失败，请重试")
                    return
                }

                Logger.capture.info("Overlay screenshot saved \(targetURL.lastPathComponent, privacy: .public)")
                self.dismiss()
            }
        }
    }

    private func saveDirectly(_ image: CGImage, to directory: URL) {
        guard !isOperating, let view = overlayView else {
            return
        }
        isOperating = true
        view.setBusy(true)

        let targetURL = FilenameAllocator.uniqueURL(
            in: directory,
            baseName: suggestedBaseName,
            fileExtension: "png"
        )

        Task { @MainActor [weak self] in
            let data = await Task.detached(priority: .userInitiated) {
                image.pngData()
            }.value

            guard let self else {
                return
            }
            self.isOperating = false
            self.overlayView?.setBusy(false)

            guard let data else {
                self.overlayView?.showToast(CaptureError.encodeFailed.localizedDescription)
                return
            }

            do {
                try data.write(to: targetURL, options: .atomic)
            } catch {
                Logger.capture.error(
                    "Overlay screenshot direct write failed: \(error.localizedDescription, privacy: .public)"
                )
                self.overlayView?.showToast("保存失败，请重试")
                return
            }

            Logger.capture.info(
                "Overlay screenshot saved directly \(targetURL.lastPathComponent, privacy: .public)"
            )
            let folder = FileManager.default.displayName(atPath: directory.path)
            self.overlayView?.showToast("已保存到「\(folder)」", autoHideAfter: 2.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.dismiss()
            }
        }
    }

    // MARK: - Share

    private func share(_ image: CGImage) {
        guard !isOperating, let view = overlayView else {
            return
        }
        isOperating = true
        view.setBusy(true)

        Task { @MainActor [weak self] in
            let data = await Task.detached(priority: .userInitiated) {
                image.pngData()
            }.value

            guard let self else {
                return
            }
            self.isOperating = false
            self.overlayView?.setBusy(false)

            guard let data else {
                self.overlayView?.showToast(CaptureError.encodeFailed.localizedDescription)
                return
            }

            guard let url = ShareFiles.writePNG(
                data: data,
                baseName: self.suggestedBaseName
            ) else {
                self.overlayView?.showToast("分享准备失败，请重试")
                return
            }

            self.presentSharePicker(for: url)
        }
    }

    private func presentSharePicker(for url: URL) {
        guard let view = overlayView else {
            return
        }
        let picker = NSSharingServicePicker(items: [url])
        sharePicker = picker
        let anchor = NSRect(
            x: view.bounds.midX - 1,
            y: max(8, imageRect.minY - 30),
            width: 2,
            height: 2
        )
        picker.show(relativeTo: anchor, of: view, preferredEdge: .minY)
        Logger.capture.info("Overlay share picker presented")
    }

    // MARK: - OCR

    private func recognize(_ image: CGImage) {
        guard !isOperating, let view = overlayView else {
            return
        }
        isOperating = true
        view.setBusy(true)
        view.showToast("正在识别文字…", autoHideAfter: nil)

        Task { @MainActor [weak self] in
            let outcome = await TextRecognizer.recognize(in: image)
            guard let self else {
                return
            }
            self.isOperating = false
            self.overlayView?.setBusy(false)
            guard let view = self.overlayView else {
                return
            }

            switch outcome {
            case .text(let text):
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                guard pasteboard.setString(text, forType: .string) else {
                    view.showToast("文字已识别，但复制失败")
                    return
                }
                Logger.capture.info("Overlay OCR copied chars=\(text.count, privacy: .public)")
                view.showToast("已识别并复制 \(text.count) 个字符")
            case .empty:
                view.showToast("没有识别到文字")
            case .failed:
                view.showToast("文字识别失败，请重试")
            }
        }
    }
}

final class CaptureResultOverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
