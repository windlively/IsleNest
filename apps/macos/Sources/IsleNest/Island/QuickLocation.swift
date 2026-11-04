import Foundation

enum QuickLocation: String, CaseIterable, Identifiable {
    case downloads, desktop, applications, home

    var id: String { rawValue }
    var title: String {
        switch self {
        case .downloads: return "下载"
        case .desktop: return "桌面"
        case .applications: return "应用程序"
        case .home: return "个人目录"
        }
    }
    var symbol: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .desktop: return "desktopcomputer"
        case .applications: return "square.grid.2x2"
        case .home: return "house"
        }
    }
    var url: URL {
        switch self {
        case .downloads: return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        case .desktop: return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        case .applications: return URL(fileURLWithPath: "/Applications", isDirectory: true)
        case .home: return FileManager.default.homeDirectoryForCurrentUser
        }
    }
}
