import Foundation

public struct PersistedState: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var settings: AppSettings
    public var folders: [FavoriteFolder]
    public var launchItems: [LaunchItem]
    public var shelfItems: [ShelfItem]

    public init(
        schemaVersion: Int = PersistedState.currentSchemaVersion,
        settings: AppSettings = AppSettings(),
        folders: [FavoriteFolder] = [],
        launchItems: [LaunchItem] = [],
        shelfItems: [ShelfItem] = []
    ) {
        self.schemaVersion = schemaVersion
        self.settings = settings
        self.folders = folders
        self.launchItems = launchItems
        self.shelfItems = shelfItems
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case settings
        case folders
        case launchItems
        case shelfItems
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        folders = try container.decodeIfPresent([FavoriteFolder].self, forKey: .folders) ?? []
        launchItems = try container.decodeIfPresent([LaunchItem].self, forKey: .launchItems) ?? []
        shelfItems = try container.decodeIfPresent([ShelfItem].self, forKey: .shelfItems) ?? []
    }
}
