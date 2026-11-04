import Foundation

public struct FavoriteFolder: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var bookmarkData: Data?
    public var path: String
    public var addedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        bookmarkData: Data? = nil,
        path: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.bookmarkData = bookmarkData
        self.path = path
        self.addedAt = addedAt
    }

    public var abbreviatedPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

public enum FolderAvailability: Equatable, Sendable {
    case available(URL)
    case missingVolume
    case missing
    case permissionDenied
    case unresolved
}
