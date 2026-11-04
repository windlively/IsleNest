import Foundation

public enum FilenameAllocator {
    public static func screenshotBaseName(
        date: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "栖岛截图 \(formatter.string(from: date))"
    }

    public static func recordingBaseName(
        date: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "栖岛录屏 \(formatter.string(from: date))"
    }

    public static func uniqueURL(
        in directory: URL,
        baseName: String,
        fileExtension: String,
        fileManager: FileManager = .default
    ) -> URL {
        let suffix = fileExtension.hasPrefix(".") ? fileExtension : ".\(fileExtension)"
        var candidate = directory.appendingPathComponent(baseName + suffix)
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) \(counter)\(suffix)")
            counter += 1
        }
        return candidate
    }

    public static func uniqueURL(
        for preferredURL: URL,
        fileManager: FileManager = .default
    ) -> URL {
        guard fileManager.fileExists(atPath: preferredURL.path) else {
            return preferredURL
        }

        let directory = preferredURL.deletingLastPathComponent()
        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        let fileExtension = preferredURL.pathExtension
        return uniqueURL(
            in: directory,
            baseName: baseName,
            fileExtension: fileExtension,
            fileManager: fileManager
        )
    }
}
