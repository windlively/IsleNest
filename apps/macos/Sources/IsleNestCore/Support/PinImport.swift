import Foundation

public struct PinImportResult {
    public var folders = 0
    public var launchItems = 0
    public var duplicates = 0
    public var rejected = 0
    public var added: Int { folders + launchItems }
}

extension ConfigStore {
    /// Imports independently so a full section or invalid item cannot lose other additions.
    public func importPins(from urls: [URL]) -> PinImportResult {
        var result = PinImportResult()
        result.rejected = max(0, urls.count - 32)
        for url in urls.prefix(32) {
            do {
                if url.isFileURL {
                    let resource = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                    if url.pathExtension.lowercased() == "app" {
                        let added = try addApplications(at: [url])
                        result.launchItems += added.count
                        result.duplicates += added.isEmpty ? 1 : 0
                    } else if resource.isDirectory == true, resource.isPackage != true {
                        try addFolder(at: url)
                        result.folders += 1
                    } else {
                        result.rejected += 1
                    }
                } else if let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
                    try addWebsite(title: "", urlString: url.absoluteString)
                    result.launchItems += 1
                } else {
                    result.rejected += 1
                }
            } catch ConfigStoreError.duplicateFolder {
                result.duplicates += 1
            } catch ConfigStoreError.duplicateWebsite {
                result.duplicates += 1
            } catch {
                result.rejected += 1
            }
        }
        return result
    }
}
