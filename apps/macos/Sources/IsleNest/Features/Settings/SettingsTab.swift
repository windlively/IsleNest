import Foundation

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case folders
    case launch
    case capture
    case about

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .folders:
            return "文件夹"
        case .launch:
            return "快捷启动"
        case .capture:
            return "截屏"
        case .about:
            return "关于"
        }
    }

    var symbol: String {
        switch self {
        case .general:
            return "gearshape"
        case .folders:
            return "folder"
        case .launch:
            return "square.grid.2x2"
        case .capture:
            return "camera.viewfinder"
        case .about:
            return "info.circle"
        }
    }
}
