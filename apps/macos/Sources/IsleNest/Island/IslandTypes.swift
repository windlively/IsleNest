import AppKit
import Foundation
import IsleNestCore

enum CaptureKind: String, CaseIterable, Identifiable, Hashable {
    case region
    case window
    case display
    case scrolling

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .region:
            return "区域截屏"
        case .window:
            return "窗口截屏"
        case .display:
            return "全屏截屏"
        case .scrolling:
            return "滚动截屏"
        }
    }

    var shortTitle: String {
        switch self {
        case .region:
            return "区域"
        case .window:
            return "窗口"
        case .display:
            return "全屏"
        case .scrolling:
            return "滚动"
        }
    }

    var symbol: String {
        switch self {
        case .region:
            return "viewfinder"
        case .window:
            return "macwindow"
        case .display:
            return "display"
        case .scrolling:
            return "scroll"
        }
    }

    var hint: String {
        switch self {
        case .region:
            return "拖动框选屏幕区域"
        case .window:
            return "选择一个窗口截取"
        case .display:
            return "截取当前显示器"
        case .scrolling:
            return "框选后缓慢滚动，自动拼接长图"
        }
    }

    var shortcutNumber: Int? {
        switch self {
        case .region, .window, .display, .scrolling:
            return (Self.allCases.firstIndex(of: self) ?? 0) + 1
        }
    }
}

struct ScreenshotResult: Identifiable {
    let id = UUID()
    let image: CGImage
    let kind: CaptureKind
    let capturedAt: Date
    let sourceTitle: String?
    var savedURL: URL?

    let preview: NSImage

    init(image: CGImage, kind: CaptureKind, capturedAt: Date = Date(), sourceTitle: String? = nil) {
        self.image = image
        self.kind = kind
        self.capturedAt = capturedAt
        self.sourceTitle = sourceTitle
        self.preview = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
    }

    var sizeDescription: String {
        "\(image.width) × \(image.height) px"
    }

    var suggestedBaseName: String {
        FilenameAllocator.screenshotBaseName(date: capturedAt)
    }
}

struct IslandNotice: Identifiable {
    enum Kind {
        case success
        case info
        case error
    }

    struct Action: Identifiable {
        enum Style {
            case standard
            case destructive
        }

        let id = UUID()
        let title: String
        let style: Style
        let handler: () -> Void
    }

    let id = UUID()
    let kind: Kind
    let message: String
    let actions: [Action]

    init(kind: Kind, message: String, actions: [Action] = []) {
        self.kind = kind
        self.message = message
        self.actions = actions
    }
}

enum IslandFocusID: Hashable {
    case capture(CaptureKind)
    case record
    case colorPicker
    case pomodoro
    case pomodoroBack
    case pomodoroToggle
    case pomodoroReset
    case pomodoroSkip
    case recentFiles
    case recentBack
    case recentRefresh
    case recentFile(URL)
    case shelf
    case shelfBack
    case shelfAdd
    case shelfItem(UUID)
    case shelfClear
    case folder(UUID)
    case addFolder
    case manageFolders
    case launch(UUID)
    case addLaunch
    case editLaunch
    case settings
    case collapse
    case resultCopy
    case resultSave
    case resultShare
    case resultOCR
    case resultReveal
    case resultClose
    case resultRetake
    case location(QuickLocation)
    case nextFolderPage
    case nextLaunchPage
    case addWebsite
}
