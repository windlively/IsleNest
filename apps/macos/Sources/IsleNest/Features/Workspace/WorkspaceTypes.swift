import AppKit
import Combine
import Foundation
import IsleNestCore

enum WorkspaceSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case files
    case system
    case tools
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .overview:
            return "概览"
        case .files:
            return "文件"
        case .system:
            return "系统"
        case .tools:
            return "工具"
        case .settings:
            return "设置"
        }
    }

    var symbol: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .files:
            return "folder"
        case .system:
            return "gauge"
        case .tools:
            return "wrench.and.screwdriver"
        case .settings:
            return "gearshape"
        }
    }
}

enum WorkspaceFilesTab: String, CaseIterable, Identifiable, Hashable {
    case matrix
    case largeFiles

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .matrix:
            return "文件矩阵"
        case .largeFiles:
            return "大文件"
        }
    }

    var symbol: String {
        switch self {
        case .matrix:
            return "square.grid.3x3"
        case .largeFiles:
            return "doc"
        }
    }
}

@MainActor
final class WorkspaceNavigation: ObservableObject {
    @Published var section: WorkspaceSection = .overview
    @Published var settingsTab: SettingsTab = .general
    @Published var filesTab: WorkspaceFilesTab = .matrix
}

@MainActor
final class WorkspaceServices {
    let systemMonitor = SystemMonitor()
    let largeFileScanner = LargeFileScanner()
    let fileMatrix = FileMatrixScanner()
    let pomodoro: PomodoroTimer
    let recentFiles: RecentFilesStore

    init(pomodoro: PomodoroTimer, recentFiles: RecentFilesStore) {
        self.pomodoro = pomodoro
        self.recentFiles = recentFiles
    }
}

struct WorkspaceActions {
    var capture: (CaptureKind) -> Void
    var recordRegion: () -> Void
    var sampleColor: () -> Void
    var revealFile: (URL) -> Void
}

struct WorkspaceToast: Identifiable {
    enum Kind {
        case success
        case info
        case error
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

extension WorkspaceBackdropStyle {
    var material: NSVisualEffectView.Material {
        switch self {
        case .clear:
            return .underWindowBackground
        case .frosted:
            return .sidebar
        case .dense:
            return .menu
        }
    }
}
