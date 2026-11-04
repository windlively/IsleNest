import Foundation

@MainActor
final class PomodoroTimer: ObservableObject {
    enum Phase {
        case focus
        case rest

        var title: String {
            switch self {
            case .focus: return "专注"
            case .rest: return "休息"
            }
        }

        var subtitle: String {
            switch self {
            case .focus: return "先把这一件事做完"
            case .rest: return "起身走走，看看远处"
            }
        }

        var duration: TimeInterval {
            switch self {
            case .focus: return 25 * 60
            case .rest: return 5 * 60
            }
        }
    }

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remaining: TimeInterval = Phase.focus.duration
    @Published private(set) var isRunning = false
    @Published private(set) var isActive = false
    @Published private(set) var completedFocusCount = 0

    var onPhaseCompleted: ((Phase) -> Void)?

    private var ticker: Timer?
    private var endDate: Date?

    var timeText: String {
        let total = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var progress: Double {
        let total = phase.duration
        guard total > 0 else {
            return 0
        }
        return min(1, max(0, remaining / total))
    }

    var startButtonTitle: String {
        if isRunning {
            return "暂停"
        }
        return remaining < phase.duration - 0.5 ? "继续" : "开始"
    }

    var sessionText: String {
        completedFocusCount == 0
            ? "今天还没完成番茄"
            : "今天已完成 \(completedFocusCount) 个番茄"
    }

    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        guard !isRunning else {
            return
        }
        if remaining <= 0 {
            remaining = phase.duration
        }
        isRunning = true
        endDate = Date().addingTimeInterval(remaining)
        scheduleTicker()
        updateActive()
    }

    func pause() {
        guard isRunning else {
            return
        }
        syncRemaining()
        isRunning = false
        endDate = nil
        stopTicker()
        updateActive()
    }

    func reset() {
        stopTicker()
        endDate = nil
        isRunning = false
        remaining = phase.duration
        updateActive()
    }

    func skip() {
        stopTicker()
        endDate = nil
        isRunning = false
        phase = phase == .focus ? .rest : .focus
        remaining = phase.duration
        updateActive()
    }

    private func scheduleTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard isRunning, let endDate else {
            return
        }
        let next = endDate.timeIntervalSinceNow
        if next <= 0 {
            remaining = 0
            finishPhase()
            return
        }
        remaining = next
        updateActive()
    }

    private func syncRemaining() {
        guard let endDate else {
            return
        }
        remaining = max(0, endDate.timeIntervalSinceNow)
    }

    private func finishPhase() {
        let completed = phase
        stopTicker()
        endDate = nil
        isRunning = false

        if completed == .focus {
            completedFocusCount += 1
            phase = .rest
            remaining = phase.duration
            // Break starts automatically; the next focus waits for the user.
            isRunning = true
            endDate = Date().addingTimeInterval(remaining)
            scheduleTicker()
        } else {
            phase = .focus
            remaining = phase.duration
        }
        updateActive()
        onPhaseCompleted?(completed)
    }

    private func updateActive() {
        let active = isRunning || remaining < phase.duration - 0.5
        if active != isActive {
            isActive = active
        }
    }
}
