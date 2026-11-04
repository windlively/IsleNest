import AppKit
import SwiftUI

@MainActor
final class ScreenPermissionModel: ObservableObject {
    @Published private(set) var isGranted = ScreenPermissionService.isGranted
    @Published private(set) var note: String?

    func refresh() {
        isGranted = ScreenPermissionService.isGranted
        if isGranted {
            note = nil
        }
    }

    func request() {
        guard !isGranted else {
            return
        }
        let granted = ScreenPermissionService.request()
        refresh()
        if !isGranted {
            note = granted
                ? "系统已记录授权，重新启动栖岛后生效。"
                : "尚未获得权限，请在系统设置中允许栖岛的屏幕录制。"
        }
    }

    func openSystemSettings() {
        ScreenPermissionService.openSystemSettings()
    }

    func relaunch() {
        ScreenPermissionService.relaunch()
    }
}
