import AppKit
import IsleNestCore

enum ShareFiles {
    static func writePNG(data: Data, baseName: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IsleNestShare", isDirectory: true)
        guard (try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )) != nil else {
            return nil
        }
        prune(directory)
        let url = FilenameAllocator.uniqueURL(
            in: directory,
            baseName: baseName,
            fileExtension: "png"
        )
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func prune(_ directory: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for url in contents {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if modified < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
