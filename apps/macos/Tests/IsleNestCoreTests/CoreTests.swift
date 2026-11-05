import XCTest
@testable import IsleNestCore

final class WebsiteURLTests: XCTestCase {
    func testNormalizesHostWithoutScheme() {
        XCTAssertEqual(WebsiteURL.normalize("example.com")?.absoluteString, "https://example.com")
        XCTAssertEqual(WebsiteURL.normalize("  www.example.com/docs  ")?.absoluteString, "https://www.example.com/docs")
        XCTAssertEqual(WebsiteURL.normalize("localhost:8080")?.absoluteString, "https://localhost:8080")
        XCTAssertEqual(WebsiteURL.normalize("192.168.1.10:8080/admin")?.absoluteString, "https://192.168.1.10:8080/admin")
    }

    func testPreservesHTTPAndHTTPS() {
        XCTAssertEqual(WebsiteURL.normalize("http://example.com")?.absoluteString, "http://example.com")
        XCTAssertEqual(WebsiteURL.normalize("https://example.com/a?b=1")?.absoluteString, "https://example.com/a?b=1")
    }

    func testRejectsOtherSchemesAndEmptyInput() {
        let invalid = [
            "",
            "   ",
            "ftp://example.com",
            "file:///tmp/file",
            "javascript:alert(1)",
            "mailto:hello@example.com",
            "https://"
        ]
        for value in invalid {
            XCTAssertNil(WebsiteURL.normalize(value), "应为无效网址：\(value)")
        }
    }

    func testDefaultTitleDropsWWW() {
        let url = URL(string: "https://www.example.com/path")!
        XCTAssertEqual(WebsiteURL.defaultTitle(for: url), "example.com")
    }
}

@MainActor
final class ConfigStoreTests: XCTestCase {
    private func makeBacking() -> (store: ConfigStore, defaults: UserDefaults, key: String) {
        let suiteName = "islenest.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let key = "state"
        return (ConfigStore(defaults: defaults, stateKey: key), defaults, key)
    }

    private func makeStore() -> ConfigStore {
        makeBacking().store
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("islenest-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    func testAddsFoldersAndEnforcesLimit() throws {
        let store = makeStore()
        for _ in 0..<ConfigStore.maxFolderCount {
            try store.addFolder(at: try makeTempDirectory())
        }
        XCTAssertEqual(store.folders.count, ConfigStore.maxFolderCount)

        XCTAssertThrowsError(try store.addFolder(at: try makeTempDirectory())) { error in
            XCTAssertEqual(error as? ConfigStoreError, .folderLimitReached)
        }
    }

    func testRejectsDuplicateFolder() throws {
        let store = makeStore()
        let url = try makeTempDirectory()
        try store.addFolder(at: url)

        XCTAssertThrowsError(try store.addFolder(at: url)) { error in
            XCTAssertEqual(error as? ConfigStoreError, .duplicateFolder)
        }
    }

    func testRenameMoveAndRemoveFolders() throws {
        let store = makeStore()
        let a = try store.addFolder(at: try makeTempDirectory())
        let b = try store.addFolder(at: try makeTempDirectory())
        let c = try store.addFolder(at: try makeTempDirectory())

        store.renameFolder(id: a.id, to: "  项目  ")
        XCTAssertEqual(store.folders.first(where: { $0.id == a.id })?.title, "项目")

        store.moveFolder(id: a.id, by: 1)
        XCTAssertEqual(store.folders.map(\.id), [b.id, a.id, c.id])

        store.moveFolder(id: a.id, by: 10)
        XCTAssertEqual(store.folders.map(\.id), [b.id, c.id, a.id])

        store.removeFolder(id: b.id)
        XCTAssertEqual(store.folders.map(\.id), [c.id, a.id])
    }

    func testRelocateFolderKeepsTitleAndRejectsDuplicate() throws {
        let store = makeStore()
        let original = try store.addFolder(at: try makeTempDirectory())
        let other = try store.addFolder(at: try makeTempDirectory())
        store.renameFolder(id: original.id, to: "我的项目")

        let relocated = try makeTempDirectory()
        try store.relocateFolder(id: original.id, to: relocated)
        let updated = store.folders.first(where: { $0.id == original.id })
        XCTAssertEqual(updated?.title, "我的项目")
        XCTAssertEqual(updated?.path, relocated.standardizedFileURL.path)

        let otherURL = URL(fileURLWithPath: store.folders.first(where: { $0.id == other.id })!.path)
        XCTAssertThrowsError(try store.relocateFolder(id: original.id, to: otherURL)) { error in
            XCTAssertEqual(error as? ConfigStoreError, .duplicateFolder)
        }
    }

    func testFolderAvailabilityReportsMissingDirectory() throws {
        let store = makeStore()
        let directory = try makeTempDirectory()
        let folder = try store.addFolder(at: directory)

        switch store.folderAvailability(id: folder.id) {
        case .available:
            break
        default:
            XCTFail("应识别为可用目录")
        }

        try FileManager.default.removeItem(at: directory)
        switch store.folderAvailability(id: folder.id) {
        case .missing:
            break
        default:
            XCTFail("应识别为目录缺失")
        }
    }

    func testSettingsAndItemsPersist() throws {
        let (store, defaults, key) = makeBacking()
        store.settings.trigger = .hover
        store.settings.theme = .tide
        store.settings.appearance = .light
        store.settings.displayIslandWidths["display-a"] = 184
        let folder = try store.addFolder(at: try makeTempDirectory())
        let website = try store.addWebsite(title: "", urlString: "example.com")

        let reloaded = ConfigStore(defaults: defaults, stateKey: key)
        XCTAssertEqual(reloaded.settings.trigger, .hover)
        XCTAssertEqual(reloaded.settings.theme, .tide)
        XCTAssertEqual(reloaded.settings.appearance, .light)
        XCTAssertEqual(reloaded.settings.displayIslandWidths["display-a"], 184)
        XCTAssertEqual(reloaded.folders.first?.id, folder.id)
        XCTAssertNotNil(reloaded.folders.first?.bookmarkData)
        XCTAssertEqual(reloaded.launchItems.first?.id, website.id)
        XCTAssertEqual(reloaded.launchItems.first?.title, "example.com")
        XCTAssertEqual(reloaded.launchItems.first?.urlString, "https://example.com")
    }

    func testAddsWebsitesRejectsDuplicatesAndEnforcesLimit() throws {
        let store = makeStore()
        let website = try store.addWebsite(title: "工作台", urlString: "https://example.com/team")
        XCTAssertEqual(website.title, "工作台")
        XCTAssertEqual(website.kind, .website)

        XCTAssertThrowsError(try store.addWebsite(title: "重复", urlString: "example.com/team")) { error in
            XCTAssertEqual(error as? ConfigStoreError, .duplicateWebsite)
        }
        XCTAssertThrowsError(try store.addWebsite(title: "坏链接", urlString: "file:///tmp/a")) { error in
            XCTAssertEqual(error as? ConfigStoreError, .invalidWebsite)
        }

        for index in 1..<ConfigStore.maxLaunchItemCount {
            try store.addWebsite(title: "站点 \(index)", urlString: "https://example.com/\(index)")
        }
        XCTAssertEqual(store.launchItems.count, ConfigStore.maxLaunchItemCount)
        XCTAssertThrowsError(try store.addWebsite(title: "超出", urlString: "https://example.com/overflow")) { error in
            XCTAssertEqual(error as? ConfigStoreError, .launchLimitReached)
        }
    }

    func testUpdateWebsiteAndRenameLaunchItem() throws {
        let store = makeStore()
        let website = try store.addWebsite(title: "旧标题", urlString: "https://example.com")
        try store.updateWebsite(id: website.id, title: "  新标题 ", urlString: "http://example.org/docs")

        let updated = store.launchItems.first
        XCTAssertEqual(updated?.title, "新标题")
        XCTAssertEqual(updated?.urlString, "http://example.org/docs")

        store.renameLaunchItem(id: website.id, to: "再改名")
        XCTAssertEqual(store.launchItems.first?.title, "再改名")
    }

    func testAddsApplicationsAndDeduplicates() throws {
        let appURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appURL.path), "系统计算器不存在")

        let store = makeStore()
        let added = try store.addApplications(at: [appURL, appURL])
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(store.launchItems.count, 1)
        XCTAssertEqual(store.launchItems.first?.kind, .application)
        XCTAssertNotNil(store.launchItems.first?.bundleIdentifier)
        XCTAssertNotNil(store.launchItems.first?.applicationURL)
    }

    func testResetSettingsKeepsOnboardingAndFavorites() throws {
        let store = makeStore()
        store.completeOnboarding()
        store.settings.trigger = .hover
        store.settings.style = .floating
        store.settings.theme = .ember
        store.settings.appearance = .dark
        store.settings.workspaceBackdrop = .dense
        try store.addFolder(at: try makeTempDirectory())

        store.resetSettings()

        XCTAssertEqual(store.settings.trigger, .click)
        XCTAssertEqual(store.settings.style, .automatic)
        XCTAssertEqual(store.settings.theme, .moss)
        XCTAssertEqual(store.settings.appearance, .system)
        XCTAssertEqual(store.settings.workspaceBackdrop, .frosted)
        XCTAssertTrue(store.settings.onboardingCompleted)
        XCTAssertEqual(store.folders.count, 1)
    }

    func testCorruptStateFallsBackAndKeepsBackup() {
        let suiteName = "islenest.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(Data("not-json".utf8), forKey: "state")
        let store = ConfigStore(defaults: defaults, stateKey: "state")
        XCTAssertTrue(store.folders.isEmpty)
        XCTAssertNotNil(defaults.data(forKey: "state.corrupt-backup"))
    }

    func testFutureSchemaFallsBackWithoutOverwritingBackup() throws {
        let suiteName = "islenest.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let future = PersistedState(
            schemaVersion: 999,
            settings: AppSettings(trigger: .hover),
            folders: [FavoriteFolder(title: "未来", path: "/tmp/future")]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(future), forKey: "state")

        let store = ConfigStore(defaults: defaults, stateKey: "state")
        XCTAssertEqual(store.settings.trigger, .click)
        XCTAssertTrue(store.folders.isEmpty)
        XCTAssertNotNil(defaults.data(forKey: "state.future-backup"))
    }

    func testSettingsDecodingUsesDefaultsForMissingFields() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, AppSettings())
    }
}

final class FilenameAllocatorTests: XCTestCase {
    func testScreenshotBaseNameUsesStableFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 1
        components.hour = 6
        components.minute = 7
        components.second = 8
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: components)!

        let name = FilenameAllocator.screenshotBaseName(date: date, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(name, "栖岛截图 2026-11-01 06.07.08")
    }

    func testUniqueURLAppendsCounter() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("islenest-names-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let first = FilenameAllocator.uniqueURL(in: directory, baseName: "shot", fileExtension: "png")
        XCTAssertEqual(first.lastPathComponent, "shot.png")
        try Data().write(to: first)

        let second = FilenameAllocator.uniqueURL(in: directory, baseName: "shot", fileExtension: "png")
        XCTAssertEqual(second.lastPathComponent, "shot 2.png")
        try Data().write(to: second)

        let third = FilenameAllocator.uniqueURL(for: second)
        XCTAssertEqual(third.lastPathComponent, "shot 2 2.png")
    }
}

final class BookmarkTests: XCTestCase {
    func testBookmarkRoundTripToTemporaryDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("islenest-bookmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let data = try Bookmark.create(for: directory)
        let resolution = try Bookmark.resolve(data)
        XCTAssertEqual(
            resolution.url.resolvingSymlinksInPath().path,
            directory.resolvingSymlinksInPath().path
        )
    }
}

final class FolderProbeTests: XCTestCase {
    func testDetectsUnmountedVolume() {
        let url = URL(fileURLWithPath: "/Volumes/IsleNestMissing-\(UUID().uuidString)/Projects")
        XCTAssertEqual(FolderProbe.evaluate(url), .missingVolume)
    }

    func testDetectsMissingDirectory() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("islenest-missing-\(UUID().uuidString)", isDirectory: true)
        XCTAssertEqual(FolderProbe.evaluate(url), .missing)
    }
}
