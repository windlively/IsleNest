import Foundation

public enum FolderProbe {
    public static func evaluate(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> FolderAvailability {
        if isOnMissingVolume(url, fileManager: fileManager) {
            return .missingVolume
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .missing
        }
        guard isDirectory.boolValue else {
            return .missing
        }
        guard fileManager.isReadableFile(atPath: url.path) else {
            return .permissionDenied
        }
        return .available(url)
    }

    private static func isOnMissingVolume(_ url: URL, fileManager: FileManager) -> Bool {
        let components = url.pathComponents
        guard components.count > 2, components[1] == "Volumes" else {
            return false
        }
        let volumeRoot = "/Volumes/\(components[2])"
        return !fileManager.fileExists(atPath: volumeRoot)
    }
}
