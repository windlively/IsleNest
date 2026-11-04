import Foundation

struct IslandActions {
    var toggle: () -> Void
    var collapse: () -> Void
    var capture: (CaptureKind) -> Void
    var recordRegion: () -> Void
    var addFolder: () -> Void
    var manageFolders: () -> Void
    var addLaunch: () -> Void
    var editLaunch: () -> Void
    var openFolder: (UUID) -> Void
    var openLaunch: (UUID) -> Void
    var openSettings: () -> Void
    var copyResult: () -> Void
    var saveResult: () -> Void
    var shareResult: () -> Void
    var recognizeResultText: () -> Void
    var revealResult: () -> Void
    var closeResult: () -> Void
    var dismissNotice: () -> Void
    var openLocation: (QuickLocation) -> Void
    var nextFolderPage: () -> Void
    var nextLaunchPage: () -> Void
    var pinURLs: ([URL]) -> Bool
    var dragTargetChanged: (Bool) -> Void
    var addWebsite: () -> Void
    var retakeResult: () -> Void
    var toggleShelf: () -> Void
    var togglePomodoro: () -> Void
    var pomodoroToggle: () -> Void
    var pomodoroReset: () -> Void
    var pomodoroSkip: () -> Void
    var toggleRecentFiles: () -> Void
    var refreshRecentFiles: () -> Void
    var openRecentFile: (URL) -> Void
    var revealRecentFile: (URL) -> Void
    var copyRecentPath: (URL) -> Void
    var sampleColor: () -> Void
    var addShelfFiles: () -> Void
    var shelfDrop: ([URL]) -> Bool
    var openShelfItem: (UUID) -> Void
    var revealShelfItem: (UUID) -> Void
    var copyShelfPath: (UUID) -> Void
    var shareShelfItem: (UUID) -> Void
    var removeShelfItem: (UUID) -> Void
    var clearShelf: () -> Void
}
