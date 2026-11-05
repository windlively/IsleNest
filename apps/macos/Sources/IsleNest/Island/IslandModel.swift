import Foundation
import IsleNestCore
import SwiftUI

@MainActor
final class IslandModel: ObservableObject {
    @Published var isExpanded = false
    @Published var result: ScreenshotResult?
    @Published var notice: IslandNotice?
    @Published var selectedFocus: IslandFocusID?
    @Published var keyboardFocusVisible = false
    @Published var isResultBusy = false
    @Published var folderPage = 0
    @Published var launchPage = 0
    @Published var isDropTargeted = false
    @Published var showsShelf = false
    @Published var showsPomodoro = false

    private var noticeDismissTask: Task<Void, Never>?

    func showNotice(_ notice: IslandNotice, autoDismissAfter: TimeInterval? = nil) {
        noticeDismissTask?.cancel()
        self.notice = notice

        let delay = autoDismissAfter ?? (notice.kind == .error ? nil : 3.2)
        guard let delay else {
            return
        }

        let noticeID = notice.id
        noticeDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            guard let self, self.notice?.id == noticeID else {
                return
            }
            withAnimation(.easeOut(duration: 0.18)) {
                self.notice = nil
            }
        }
    }

    func dismissNotice() {
        noticeDismissTask?.cancel()
        noticeDismissTask = nil
        withAnimation(.easeOut(duration: 0.16)) {
            notice = nil
        }
    }

    func clearResult() {
        result = nil
    }
}
