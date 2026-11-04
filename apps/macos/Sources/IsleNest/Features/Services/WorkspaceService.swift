import AppKit
import IsleNestCore

@MainActor
enum WorkspaceService {
    enum FolderOpenError: LocalizedError {
        case missingVolume
        case missing
        case permissionDenied
        case unresolved
        case openFailed

        var errorDescription: String? {
            switch self {
            case .missingVolume:
                return "所在设备未连接"
            case .missing:
                return "目录已不在原位置"
            case .permissionDenied:
                return "没有访问权限"
            case .unresolved:
                return "无法定位目录"
            case .openFailed:
                return "无法打开目录"
            }
        }
    }

    enum LaunchOpenError: LocalizedError {
        case missingApplication
        case invalidWebsite
        case openFailed

        var errorDescription: String? {
            switch self {
            case .missingApplication:
                return "应用已不存在"
            case .invalidWebsite:
                return "网址无效"
            case .openFailed:
                return "启动失败"
            }
        }
    }

    static func openFolder(id: UUID, config: ConfigStore) -> Result<Void, FolderOpenError> {
        switch config.folderAvailability(id: id) {
        case .available(let url):
            let opened = Bookmark.withAccess(to: url) {
                NSWorkspace.shared.open(url)
            }
            return opened ? .success(()) : .failure(.openFailed)
        case .missingVolume:
            return .failure(.missingVolume)
        case .missing:
            return .failure(.missing)
        case .permissionDenied:
            return .failure(.permissionDenied)
        case .unresolved:
            return .failure(.unresolved)
        }
    }

    static func openLaunchItem(_ item: LaunchItem) -> Result<Void, LaunchOpenError> {
        switch item.kind {
        case .application:
            let url = item.applicationURL
                ?? item.bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            guard let url else {
                return .failure(.missingApplication)
            }
            return NSWorkspace.shared.open(url) ? .success(()) : .failure(.openFailed)

        case .website:
            guard let url = item.websiteURL else {
                return .failure(.invalidWebsite)
            }
            return NSWorkspace.shared.open(url) ? .success(()) : .failure(.openFailed)
        }
    }
}
