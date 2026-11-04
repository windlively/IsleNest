import Foundation

public enum ConfigStoreError: LocalizedError, Equatable {
    case folderLimitReached
    case folderNotFound
    case duplicateFolder
    case notADirectory
    case launchLimitReached
    case launchItemNotFound
    case invalidWebsite
    case duplicateWebsite
    case notApplication

    public var errorDescription: String? {
        switch self {
        case .folderLimitReached:
            return "最多只能固定 8 个文件夹"
        case .folderNotFound:
            return "文件夹记录已不存在"
        case .duplicateFolder:
            return "这个文件夹已经固定过了"
        case .notADirectory:
            return "选择的项目不是文件夹"
        case .launchLimitReached:
            return "快捷启动最多只能保留 8 项"
        case .launchItemNotFound:
            return "快捷启动项已不存在"
        case .invalidWebsite:
            return "请输入有效的 http 或 https 网址"
        case .duplicateWebsite:
            return "这个网页已经添加过了"
        case .notApplication:
            return "请选择一个 macOS 应用"
        }
    }
}
