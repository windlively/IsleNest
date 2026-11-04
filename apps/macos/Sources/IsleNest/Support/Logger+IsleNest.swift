import Foundation
import os

extension Logger {
    static let island = Logger(subsystem: "app.islenest.mac", category: "island")
    static let capture = Logger(subsystem: "app.islenest.mac", category: "capture")
    static let folders = Logger(subsystem: "app.islenest.mac", category: "folders")
    static let launch = Logger(subsystem: "app.islenest.mac", category: "launch")
    static let lifecycle = Logger(subsystem: "app.islenest.mac", category: "lifecycle")
}
