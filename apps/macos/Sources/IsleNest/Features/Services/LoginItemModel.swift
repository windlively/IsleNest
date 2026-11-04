import Foundation
import ServiceManagement
import os

@MainActor
final class LoginItemModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var statusDetail: String?
    @Published var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            isEnabled = true
            statusDetail = nil
        case .requiresApproval:
            isEnabled = false
            statusDetail = "已在系统设置中关闭，需要允许后才能登录启动"
        case .notRegistered:
            isEnabled = false
            statusDetail = nil
        case .notFound:
            isEnabled = false
            statusDetail = "当前运行位置不支持登录启动，请将应用移入“应用程序”后再试"
        @unknown default:
            isEnabled = false
            statusDetail = "无法读取登录项状态"
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            Logger.lifecycle.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }
}
