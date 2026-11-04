import Foundation

public struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var path: String
    public var bookmarkData: Data?
    public var addedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        path: String,
        bookmarkData: Data? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
    }

    public var fileURL: URL {
        URL(fileURLWithPath: path)
    }

    public var abbreviatedPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

public struct ShelfImportResult: Equatable, Sendable {
    public var added = 0
    public var duplicates = 0
    public var rejected = 0
    public var limitReached = false

    public init() {}
}
