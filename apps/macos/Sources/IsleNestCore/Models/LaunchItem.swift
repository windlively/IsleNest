import Foundation

public enum LaunchItemKind: String, Codable, CaseIterable, Sendable {
    case application
    case website
}

public struct LaunchItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: LaunchItemKind
    public var title: String
    public var bundleIdentifier: String?
    public var bookmarkData: Data?
    public var path: String?
    public var urlString: String?

    public init(
        id: UUID = UUID(),
        kind: LaunchItemKind,
        title: String,
        bundleIdentifier: String? = nil,
        bookmarkData: Data? = nil,
        path: String? = nil,
        urlString: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.bookmarkData = bookmarkData
        self.path = path
        self.urlString = urlString
    }

    public var websiteURL: URL? {
        guard kind == .website, let urlString else {
            return nil
        }
        return WebsiteURL.normalize(urlString)
    }

    public var applicationURL: URL? {
        guard kind == .application else {
            return nil
        }
        if let bookmarkData, let resolution = try? Bookmark.resolve(bookmarkData) {
            if FileManager.default.fileExists(atPath: resolution.url.path) {
                return resolution.url
            }
        }
        if let path, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
