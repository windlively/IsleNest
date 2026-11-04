import AppKit
import ScreenCaptureKit
import os

enum CaptureError: LocalizedError {
    case permissionDenied
    case displayUnavailable
    case windowUnavailable
    case noWindows
    case cropFailed
    case captureFailed
    case encodeFailed
    case writeFailed
    case recordingFailed
    case recordingEmpty

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要屏幕录制权限才能截屏"
        case .displayUnavailable:
            return "当前显示器不可捕获"
        case .windowUnavailable:
            return "窗口已关闭或不可捕获"
        case .noWindows:
            return "没有找到可截取的窗口"
        case .cropFailed:
            return "选区无法生成图片"
        case .captureFailed:
            return "截屏失败，请重试"
        case .encodeFailed:
            return "无法生成 PNG 图片"
        case .writeFailed:
            return "写入文件失败"
        case .recordingFailed:
            return "录屏失败，请重试"
        case .recordingEmpty:
            return "没有录到画面，请重新录制"
        }
    }
}

@MainActor
final class CaptureService {
    func captureDisplay(_ screen: NSScreen) async throws -> CGImage {
        guard ScreenPermissionService.isGranted else {
            throw CaptureError.permissionDenied
        }

        let content = try await shareableContent()
        guard let displayID = screen.displayID,
              let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayUnavailable
        }

        let ownApplication = content.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let excludedApplications = ownApplication.map { [$0] } ?? []
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )

        let scale = CGFloat(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((screen.frame.width * scale).rounded()))
        configuration.height = max(1, Int((screen.frame.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.captureResolution = .best

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw mapped(error)
        }
    }

    func captureRegion(
        _ rect: CGRect,
        on screen: NSScreen
    ) async throws -> CGImage {
        let fullImage = try await captureDisplay(screen)
        let scaleX = CGFloat(fullImage.width) / screen.frame.width
        let scaleY = CGFloat(fullImage.height) / screen.frame.height

        let pixelRect = CGRect(
            x: rect.minX * scaleX,
            y: rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral
        let bounds = CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height)
        let clipped = pixelRect.intersection(bounds)

        guard clipped.width >= 1, clipped.height >= 1,
              let cropped = fullImage.cropping(to: clipped) else {
            throw CaptureError.cropFailed
        }
        return cropped
    }

    func availableWindows() async throws -> [SCWindow] {
        guard ScreenPermissionService.isGranted else {
            throw CaptureError.permissionDenied
        }

        let content = try await shareableContent()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let windows = content.windows.filter { window in
            guard window.isOnScreen,
                  window.windowLayer == 0,
                  window.frame.width >= 120,
                  window.frame.height >= 80,
                  let application = window.owningApplication,
                  application.processID != ownPID else {
                return false
            }
            return true
        }

        return windows.sorted { lhs, rhs in
            let leftApp = lhs.owningApplication?.applicationName ?? ""
            let rightApp = rhs.owningApplication?.applicationName ?? ""
            if leftApp.localizedCaseInsensitiveCompare(rightApp) != .orderedSame {
                return leftApp.localizedCaseInsensitiveCompare(rightApp) == .orderedAscending
            }
            let leftTitle = lhs.title ?? ""
            let rightTitle = rhs.title ?? ""
            return leftTitle.localizedCaseInsensitiveCompare(rightTitle) == .orderedAscending
        }
    }

    func captureWindow(_ window: SCWindow) async throws -> CGImage {
        guard ScreenPermissionService.isGranted else {
            throw CaptureError.permissionDenied
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let pointSize = window.frame.size

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((pointSize.width * scale).rounded()))
        configuration.height = max(1, Int((pointSize.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        configuration.ignoreShadowsSingleWindow = true
        configuration.ignoreGlobalClipSingleWindow = true

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw mapped(error)
        }
    }

    func thumbnail(for window: SCWindow, maximumSize: CGSize = CGSize(width: 360, height: 200)) async -> NSImage? {
        guard ScreenPermissionService.isGranted else {
            return nil
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let pointSize = window.frame.size
        guard pointSize.width > 0, pointSize.height > 0 else {
            return nil
        }

        let aspect = pointSize.width / pointSize.height
        var width = maximumSize.width
        var height = width / aspect
        if height > maximumSize.height {
            height = maximumSize.height
            width = height * aspect
        }

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(width * 1.6))
        configuration.height = max(1, Int(height * 1.6))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        configuration.ignoreShadowsSingleWindow = true
        configuration.ignoreGlobalClipSingleWindow = true

        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            return NSImage(cgImage: image, size: NSSize(width: width, height: height))
        } catch {
            Logger.capture.debug("Thumbnail failed: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    private func shareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw mapped(error)
        }
    }

    private func mapped(_ error: Error) -> CaptureError {
        let nsError = error as NSError
        Logger.capture.error(
            "Screen capture error domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
        if !ScreenPermissionService.isGranted {
            return .permissionDenied
        }
        return .captureFailed
    }
}
