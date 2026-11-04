import Combine
import Foundation

@MainActor
public final class ConfigStore: ObservableObject {
    public static let maxFolderCount = 8
    public static let maxLaunchItemCount = 8
    public static let maxShelfItemCount = 12
    public static let homeItemCount = 4

    @Published public var settings: AppSettings {
        didSet { persist() }
    }

    @Published public private(set) var folders: [FavoriteFolder] {
        didSet { persist() }
    }

    @Published public private(set) var launchItems: [LaunchItem] {
        didSet { persist() }
    }

    @Published public private(set) var shelfItems: [ShelfItem] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let stateKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        stateKey: String = "app.islenest.state"
    ) {
        self.defaults = defaults
        self.stateKey = stateKey

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let loaded = Self.loadState(
            from: defaults,
            key: stateKey,
            decoder: decoder
        )
        settings = loaded.settings
        folders = Array(loaded.folders.prefix(Self.maxFolderCount))
        launchItems = Array(loaded.launchItems.prefix(Self.maxLaunchItemCount))
        shelfItems = Array(loaded.shelfItems.prefix(Self.maxShelfItemCount))
    }

    // MARK: - Settings

    public func resetSettings() {
        settings = AppSettings(onboardingCompleted: settings.onboardingCompleted)
    }

    public func completeOnboarding() {
        guard !settings.onboardingCompleted else {
            return
        }
        settings.onboardingCompleted = true
    }

    // MARK: - Folders

    @discardableResult
    public func addFolder(at url: URL) throws -> FavoriteFolder {
        guard folders.count < Self.maxFolderCount else {
            throw ConfigStoreError.folderLimitReached
        }

        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ConfigStoreError.notADirectory
        }

        let key = Self.pathKey(for: standardized)
        guard !folders.contains(where: { Self.pathKey(for: URL(fileURLWithPath: $0.path)) == key }) else {
            throw ConfigStoreError.duplicateFolder
        }

        let displayName = FileManager.default.displayName(atPath: standardized.path)
        let title = displayName.isEmpty ? standardized.lastPathComponent : displayName
        let folder = FavoriteFolder(
            title: title,
            bookmarkData: try? Bookmark.create(for: standardized),
            path: standardized.path
        )
        folders.append(folder)
        return folder
    }

    public func renameFolder(id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = folders.firstIndex(where: { $0.id == id }),
              folders[index].title != trimmed else {
            return
        }
        folders[index].title = trimmed
    }

    public func removeFolder(id: UUID) {
        folders.removeAll { $0.id == id }
    }

    public func moveFolder(id: UUID, by offset: Int) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            return
        }
        let target = min(max(index + offset, 0), folders.count - 1)
        guard target != index else {
            return
        }
        let folder = folders.remove(at: index)
        folders.insert(folder, at: target)
    }

    public func relocateFolder(id: UUID, to url: URL) throws {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw ConfigStoreError.folderNotFound
        }

        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ConfigStoreError.notADirectory
        }

        let key = Self.pathKey(for: standardized)
        let duplicate = folders.enumerated().contains { offset, folder in
            offset != index && Self.pathKey(for: URL(fileURLWithPath: folder.path)) == key
        }
        guard !duplicate else {
            throw ConfigStoreError.duplicateFolder
        }

        folders[index].bookmarkData = try? Bookmark.create(for: standardized)
        folders[index].path = standardized.path
    }

    public func resolveFolder(id: UUID) throws -> URL {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw ConfigStoreError.folderNotFound
        }

        var folder = folders[index]
        if let bookmarkData = folder.bookmarkData,
           let resolution = try? Bookmark.resolve(bookmarkData) {
            if resolution.isStale,
               let refreshed = try? Bookmark.create(for: resolution.url) {
                folder.bookmarkData = refreshed
                folder.path = resolution.url.path
                folders[index] = folder
            }
            return resolution.url
        }

        guard !folder.path.isEmpty else {
            throw ConfigStoreError.folderNotFound
        }
        return URL(fileURLWithPath: folder.path)
    }

    public func folderAvailability(id: UUID) -> FolderAvailability {
        do {
            let url = try resolveFolder(id: id)
            return Bookmark.withAccess(to: url) {
                FolderProbe.evaluate(url)
            }
        } catch {
            return .unresolved
        }
    }

    // MARK: - Launch items

    @discardableResult
    public func addApplications(at urls: [URL]) throws -> [LaunchItem] {
        var working = launchItems
        var added: [LaunchItem] = []

        for url in urls {
            guard working.count < Self.maxLaunchItemCount else {
                throw ConfigStoreError.launchLimitReached
            }

            let standardized = url.standardizedFileURL
            guard standardized.pathExtension.lowercased() == "app" else {
                throw ConfigStoreError.notApplication
            }

            let bundle = Bundle(url: standardized)
            let bundleIdentifier = bundle?.bundleIdentifier

            let isDuplicate = working.contains { item in
                guard item.kind == .application else {
                    return false
                }
                if let bundleIdentifier,
                   !bundleIdentifier.isEmpty,
                   item.bundleIdentifier == bundleIdentifier {
                    return true
                }
                if let itemPath = item.path,
                   Self.pathKey(for: URL(fileURLWithPath: itemPath)) == Self.pathKey(for: standardized) {
                    return true
                }
                return false
            }
            guard !isDuplicate else {
                continue
            }

            let item = LaunchItem(
                kind: .application,
                title: Self.applicationTitle(for: standardized),
                bundleIdentifier: bundleIdentifier,
                bookmarkData: try? Bookmark.create(for: standardized),
                path: standardized.path
            )
            working.append(item)
            added.append(item)
        }

        if !added.isEmpty {
            launchItems = working
        }
        return added
    }

    @discardableResult
    public func addWebsite(title: String, urlString: String) throws -> LaunchItem {
        guard launchItems.count < Self.maxLaunchItemCount else {
            throw ConfigStoreError.launchLimitReached
        }
        guard let url = WebsiteURL.normalize(urlString) else {
            throw ConfigStoreError.invalidWebsite
        }
        guard !launchItems.contains(where: { $0.websiteURL?.absoluteString.lowercased() == url.absoluteString.lowercased() }) else {
            throw ConfigStoreError.duplicateWebsite
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = LaunchItem(
            kind: .website,
            title: trimmed.isEmpty ? WebsiteURL.defaultTitle(for: url) : trimmed,
            urlString: url.absoluteString
        )
        launchItems.append(item)
        return item
    }

    public func renameLaunchItem(id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = launchItems.firstIndex(where: { $0.id == id }),
              launchItems[index].title != trimmed else {
            return
        }
        launchItems[index].title = trimmed
    }

    public func updateWebsite(id: UUID, title: String, urlString: String) throws {
        guard let index = launchItems.firstIndex(where: { $0.id == id }),
              launchItems[index].kind == .website else {
            throw ConfigStoreError.launchItemNotFound
        }
        guard let url = WebsiteURL.normalize(urlString) else {
            throw ConfigStoreError.invalidWebsite
        }
        let duplicate = launchItems.enumerated().contains { offset, item in
            offset != index &&
                item.kind == .website &&
                item.websiteURL?.absoluteString.lowercased() == url.absoluteString.lowercased()
        }
        guard !duplicate else {
            throw ConfigStoreError.duplicateWebsite
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        launchItems[index].title = trimmed.isEmpty ? WebsiteURL.defaultTitle(for: url) : trimmed
        launchItems[index].urlString = url.absoluteString
    }

    public func removeLaunchItem(id: UUID) {
        launchItems.removeAll { $0.id == id }
    }

    public func moveLaunchItem(id: UUID, by offset: Int) {
        guard let index = launchItems.firstIndex(where: { $0.id == id }) else {
            return
        }
        let target = min(max(index + offset, 0), launchItems.count - 1)
        guard target != index else {
            return
        }
        let item = launchItems.remove(at: index)
        launchItems.insert(item, at: target)
    }

    // MARK: - Shelf

    @discardableResult
    public func addShelfItems(at urls: [URL]) -> ShelfImportResult {
        var result = ShelfImportResult()
        var working = shelfItems

        for url in urls.prefix(32) {
            guard url.isFileURL else {
                result.rejected += 1
                continue
            }
            guard working.count < Self.maxShelfItemCount else {
                result.limitReached = true
                result.rejected += 1
                continue
            }

            let standardized = url.standardizedFileURL.resolvingSymlinksInPath()
            guard FileManager.default.fileExists(atPath: standardized.path) else {
                result.rejected += 1
                continue
            }

            let key = Self.pathKey(for: standardized)
            guard !working.contains(where: { Self.pathKey(for: URL(fileURLWithPath: $0.path)) == key }) else {
                result.duplicates += 1
                continue
            }

            let displayName = FileManager.default.displayName(atPath: standardized.path)
            working.append(
                ShelfItem(
                    title: displayName.isEmpty ? standardized.lastPathComponent : displayName,
                    path: standardized.path,
                    bookmarkData: try? Bookmark.create(for: standardized)
                )
            )
            result.added += 1
        }

        if result.added > 0 {
            shelfItems = working
        }
        return result
    }

    public func removeShelfItem(id: UUID) {
        shelfItems.removeAll { $0.id == id }
    }

    public func clearShelf() {
        guard !shelfItems.isEmpty else {
            return
        }
        shelfItems = []
    }

    public func resolveShelfItem(id: UUID) -> URL? {
        guard let index = shelfItems.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        var item = shelfItems[index]
        if let bookmarkData = item.bookmarkData,
           let resolution = try? Bookmark.resolve(bookmarkData) {
            if resolution.isStale,
               let refreshed = try? Bookmark.create(for: resolution.url) {
                item.bookmarkData = refreshed
                item.path = resolution.url.path
                shelfItems[index] = item
            }
            return resolution.url
        }

        return item.path.isEmpty ? nil : URL(fileURLWithPath: item.path)
    }

    // MARK: - Persistence

    private func persist() {
        let state = PersistedState(
            settings: settings,
            folders: folders,
            launchItems: launchItems,
            shelfItems: shelfItems
        )
        guard let data = try? encoder.encode(state) else {
            return
        }
        defaults.set(data, forKey: stateKey)
    }

    private static func loadState(
        from defaults: UserDefaults,
        key: String,
        decoder: JSONDecoder
    ) -> PersistedState {
        guard let data = defaults.data(forKey: key) else {
            return PersistedState()
        }

        do {
            let state = try decoder.decode(PersistedState.self, from: data)
            guard state.schemaVersion <= PersistedState.currentSchemaVersion else {
                defaults.set(data, forKey: "\(key).future-backup")
                return PersistedState()
            }
            return state
        } catch {
            defaults.set(data, forKey: "\(key).corrupt-backup")
            return PersistedState()
        }
    }

    private static func pathKey(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
    }

    private static func applicationTitle(for url: URL) -> String {
        let displayName = FileManager.default.displayName(atPath: url.path)
        if !displayName.isEmpty {
            return displayName
        }
        let bundle = Bundle(url: url)
        if let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.isEmpty {
            return name
        }
        if let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
