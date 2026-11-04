import AppKit
import IsleNestCore

@MainActor
final class ScrollingCaptureController {
    private let captureService = CaptureService()
    private let hud = CaptureHUDController()
    private var continuation: CheckedContinuation<CGImage?, Never>?
    private var loopTask: Task<Void, Never>?
    private var finishRequested = false
    private var cancelRequested = false

    func run(region: CGRect, on screen: NSScreen) async -> CGImage? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            begin(region: region, on: screen)
        }
    }

    func cancel() {
        guard continuation != nil else {
            return
        }
        cancelRequested = true
        loopTask?.cancel()
    }

    private func begin(region: CGRect, on screen: NSScreen) {
        finishRequested = false
        cancelRequested = false

        let stitcher = ScrollingStitcherWorker()
        hud.show(
            on: screen,
            kind: .scrolling,
            title: "滚动截屏",
            detail: "正在截取第一帧…",
            actionTitle: "完成",
            highlightRect: region,
            highlightColor: .systemBlue,
            onFinish: { [weak self] in
                guard let self else {
                    return
                }
                self.finishRequested = true
                self.hud.update(detail: "正在生成结果…")
                self.loopTask?.cancel()
            },
            onCancel: { [weak self] in
                guard let self else {
                    return
                }
                self.cancelRequested = true
                self.hud.update(detail: "正在取消…")
                self.loopTask?.cancel()
            }
        )

        loopTask = Task { [weak self] in
            guard let self else {
                return
            }

            var skippedFrames = 0
            var isFirstCapture = true
            let deadline = Date().addingTimeInterval(180)

            while !Task.isCancelled, Date() < deadline {
                if self.finishRequested || self.cancelRequested {
                    break
                }

                do {
                    let frame = try await self.captureService.captureRegion(region, on: screen)
                    let result = await stitcher.append(frame)
                    let hint: String

                    switch result.outcome {
                    case .started:
                        hint = "缓慢向下滚动"
                    case .appended:
                        skippedFrames = 0
                        hint = "继续滚动"
                    case .duplicate:
                        hint = "等待滚动"
                    case .noMatch:
                        skippedFrames += 1
                        hint = skippedFrames >= 2 ? "未找到重叠区域，请放慢滚动" : "正在对齐…"
                    case .limitReached:
                        self.finishRequested = true
                        hint = "已达长度上限"
                    }

                    if skippedFrames >= 2, case .noMatch = result.outcome {
                        self.hud.update(detail: hint)
                    } else {
                        self.hud.update(
                            detail: "\(result.appendedFrames) 帧 · 高 \(result.totalHeight) px · \(hint)"
                        )
                    }
                } catch {
                    self.hud.update(detail: "截取中断，将保留已拼接内容")
                    break
                }

                if isFirstCapture {
                    isFirstCapture = false
                }
                try? await Task.sleep(nanoseconds: 520_000_000)
            }

            let image = self.cancelRequested ? nil : await stitcher.image()
            self.finishRequested = false
            self.cancelRequested = false
            self.loopTask = nil
            self.hud.dismiss()
            self.continuation?.resume(returning: image)
            self.continuation = nil
        }
    }
}

// Stitching composes full-height images; keep it off the main thread so the
// HUD and the Finish button stay responsive while a long capture is running.
private final class ScrollingStitcherWorker: @unchecked Sendable {
    struct AppendResult {
        let outcome: ScrollStitcher.AppendResult
        let appendedFrames: Int
        let totalHeight: Int
    }

    private let queue = DispatchQueue(label: "app.islenest.scrolling-stitch")
    private var stitcher = ScrollStitcher()

    func append(_ frame: CGImage) async -> AppendResult {
        await withCheckedContinuation { continuation in
            queue.async {
                let outcome = self.stitcher.append(frame)
                continuation.resume(
                    returning: AppendResult(
                        outcome: outcome,
                        appendedFrames: self.stitcher.appendedFrames,
                        totalHeight: self.stitcher.totalHeight
                    )
                )
            }
        }
    }

    func image() async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.stitcher.image)
            }
        }
    }
}
