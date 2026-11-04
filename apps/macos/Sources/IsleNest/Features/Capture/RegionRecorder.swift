import AVFoundation
import AppKit
import IsleNestCore
import ScreenCaptureKit
import os

final class RegionRecorder: NSObject, @unchecked Sendable {
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "app.islenest.region-recording")

    // Confined to sampleQueue once the stream starts.
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var temporaryURL: URL?
    private var sessionStarted = false
    private var destinationDirectory: URL?

    var isRecording: Bool {
        stream != nil
    }

    @MainActor
    func start(region: CGRect, on screen: NSScreen, directory: URL? = nil) async throws {
        guard ScreenPermissionService.isGranted else {
            throw CaptureError.permissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw mapped(error)
        }

        guard let displayID = screen.displayID,
              let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayUnavailable
        }

        let ownApplication = content.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: ownApplication.map { [$0] } ?? [],
            exceptingWindows: []
        )

        let scale = CGFloat(filter.pointPixelScale)
        var pixelWidth = max(2, Int((region.width * scale).rounded()))
        var pixelHeight = max(2, Int((region.height * scale).rounded()))
        pixelWidth -= pixelWidth % 2
        pixelHeight -= pixelHeight % 2

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = region
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 6
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("islenest-recording-\(UUID().uuidString).mp4")
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw CaptureError.recordingFailed
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(4_000_000, pixelWidth * pixelHeight * 6),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw CaptureError.recordingFailed
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw CaptureError.recordingFailed
        }

        self.writer = writer
        self.input = input
        self.temporaryURL = url
        self.sessionStarted = false
        self.destinationDirectory = directory

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
            try await stream.startCapture()
        } catch {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            clearState()
            throw mapped(error)
        }

        self.stream = stream
    }

    @MainActor
    func stop() async throws -> URL {
        guard let stream, let writer, let input, let temporaryURL else {
            throw CaptureError.recordingFailed
        }

        try? await stream.stopCapture()
        self.stream = nil

        let started = sampleQueue.sync { sessionStarted }
        guard started else {
            input.markAsFinished()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: temporaryURL)
            clearState()
            throw CaptureError.recordingEmpty
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        sampleQueue.sync {
            clearState()
        }

        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw CaptureError.recordingFailed
        }

        let target = try Self.destinationURL(in: destinationDirectory)
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: target)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw CaptureError.writeFailed
        }

        return target
    }

    @MainActor
    func cancel() async {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        sampleQueue.sync {
            input?.markAsFinished()
            writer?.cancelWriting()
            if let temporaryURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            clearState()
        }
    }

    private func clearState() {
        writer = nil
        input = nil
        temporaryURL = nil
        sessionStarted = false
    }

    private static func destinationURL(in directory: URL?) throws -> URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        var folder = movies
        if let directory {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                folder = directory
            }
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return FilenameAllocator.uniqueURL(
            in: folder,
            baseName: FilenameAllocator.recordingBaseName(),
            fileExtension: "mp4"
        )
    }

    @MainActor
    private func mapped(_ error: Error) -> CaptureError {
        let nsError = error as NSError
        Logger.capture.error(
            "Region recording error domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
        if !ScreenPermissionService.isGranted {
            return .permissionDenied
        }
        return .recordingFailed
    }
}

extension RegionRecorder: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen,
              sampleBuffer.isValid,
              CMSampleBufferGetImageBuffer(sampleBuffer) != nil,
              let writer,
              let input,
              writer.status == .writing else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !sessionStarted {
            writer.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }
        guard input.isReadyForMoreMediaData else {
            return
        }
        input.append(sampleBuffer)
    }
}
