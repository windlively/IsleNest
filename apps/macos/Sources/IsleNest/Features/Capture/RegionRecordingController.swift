import AppKit

@MainActor
final class RegionRecordingController {
    private let hud = CaptureHUDController()
    private var recorder: RegionRecorder?
    private var startTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<URL, Error>?
    private var isFinalizing = false
    private var startedAt = Date()
    private var pixelSize = CGSize.zero

    func run(region: CGRect, on screen: NSScreen, directory: URL? = nil) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            start(region: region, on: screen, directory: directory)
        }
    }

    func cancel() {
        guard continuation != nil else {
            return
        }
        Task { [weak self] in
            await self?.finalize(cancel: true)
        }
    }

    private func start(region: CGRect, on screen: NSScreen, directory: URL?) {
        hud.show(
            on: screen,
            kind: .recording,
            title: "区域录屏",
            detail: "正在准备录制…",
            actionTitle: "停止",
            highlightRect: region,
            onFinish: { [weak self] in
                Task { await self?.finalize(cancel: false) }
            },
            onCancel: { [weak self] in
                Task { await self?.finalize(cancel: true) }
            }
        )

        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else {
                return
            }

            let recorder = RegionRecorder()
            self.recorder = recorder
            do {
                try await recorder.start(region: region, on: screen, directory: directory)
            } catch {
                self.hud.dismiss()
                self.loopFinish(.failure(error))
                return
            }

            guard !self.isFinalizing, self.continuation != nil else {
                await recorder.cancel()
                return
            }

            self.startedAt = Date()
            self.pixelSize = region.size
            self.startTimer()
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                let elapsed = Int(Date().timeIntervalSince(self.startedAt))
                let minutes = elapsed / 60
                let seconds = elapsed % 60
                self.hud.update(
                    detail: String(
                        format: "%02d:%02d · %.0f × %.0f · 录制中",
                        minutes,
                        seconds,
                        self.pixelSize.width,
                        self.pixelSize.height
                    )
                )
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
        }
    }

    private func finalize(cancel: Bool) async {
        guard !isFinalizing else {
            return
        }
        isFinalizing = true
        timerTask?.cancel()
        timerTask = nil

        guard let recorder else {
            startTask?.cancel()
            hud.dismiss()
            loopFinish(.failure(CancellationError()))
            return
        }

        if cancel {
            await recorder.cancel()
            hud.dismiss()
            loopFinish(.failure(CancellationError()))
            return
        }

        do {
            let url = try await recorder.stop()
            hud.dismiss()
            loopFinish(.success(url))
        } catch {
            hud.dismiss()
            loopFinish(.failure(error))
        }
    }

    private func loopFinish(_ result: Result<URL, Error>) {
        startTask?.cancel()
        startTask = nil
        recorder = nil
        isFinalizing = false
        continuation?.resume(with: result)
        continuation = nil
    }
}
