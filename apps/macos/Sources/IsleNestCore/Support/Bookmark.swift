import Foundation

public enum BookmarkError: Error, Equatable {
    case creationFailed
    case resolutionFailed
}

public enum Bookmark {
    public struct Resolution {
        public let url: URL
        public let isStale: Bool

        public init(url: URL, isStale: Bool) {
            self.url = url
            self.isStale = isStale
        }
    }

    public static func create(for url: URL) throws -> Data {
        if let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return data
        }

        do {
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.creationFailed
        }
    }

    public static func resolve(_ data: Data) throws -> Resolution {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return Resolution(url: url, isStale: isStale)
        }

        isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return Resolution(url: url, isStale: isStale)
        } catch {
            throw BookmarkError.resolutionFailed
        }
    }

    @discardableResult
    public static func withAccess<T>(to url: URL, _ body: () throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }
}
