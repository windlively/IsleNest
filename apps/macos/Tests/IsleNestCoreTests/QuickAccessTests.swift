import XCTest
@testable import IsleNestCore

final class ItemPageTests: XCTestCase {
    func testSecondPageContainsPreviouslyHiddenFavorites() {
        let page = ItemPage(Array(1...8), index: 1)
        XCTAssertEqual(page.items, [5, 6, 7, 8])
        XCTAssertEqual(page.count, 2)
    }

    func testRemovingLastItemOnSecondPageFallsBackToFirstPage() {
        let page = ItemPage(Array(1...4), index: 1)
        XCTAssertEqual(page.index, 0)
        XCTAssertEqual(page.items, [1, 2, 3, 4])
        XCTAssertEqual(ItemPage([Int](), index: 5).items, [])
    }
}

@MainActor
final class PinImportTests: XCTestCase {
    private func fixture() throws -> (ConfigStore, URL) {
        let suite = "islenest.import-tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        return (ConfigStore(defaults: defaults), folder)
    }

    func testMixedDropAddsSupportedItemsWithoutMovingFiles() throws {
        let (store, folder) = try fixture()
        let file = folder.appendingPathComponent("keep.txt")
        try Data("untouched".utf8).write(to: file)
        let result = store.importPins(from: [folder, file, URL(string: "https://example.com")!, URL(string: "javascript:alert(1)")!])
        XCTAssertEqual(result.folders, 1)
        XCTAssertEqual(result.launchItems, 1)
        XCTAssertEqual(result.rejected, 2)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "untouched")
    }

    func testRepeatedDropDoesNotDuplicatePins() throws {
        let (store, folder) = try fixture()
        let url = URL(string: "https://example.com")!
        _ = store.importPins(from: [folder, url])
        let result = store.importPins(from: [folder, url])
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.duplicates, 2)
        XCTAssertEqual(store.folders.count, 1)
        XCTAssertEqual(store.launchItems.count, 1)
    }

    func testFullLaunchSectionStillAcceptsFolderAndPreservesExistingItems() throws {
        let (store, folder) = try fixture()
        for n in 0..<ConfigStore.maxLaunchItemCount {
            try store.addWebsite(title: "", urlString: "https://example.com/\(n)")
        }
        let original = store.launchItems
        let result = store.importPins(from: [URL(string: "https://example.com/overflow")!, folder])
        XCTAssertEqual(result.rejected, 1)
        XCTAssertEqual(result.folders, 1)
        XCTAssertEqual(store.launchItems, original)
    }

    func testApplicationPackageBecomesLauncherInsteadOfFolder() throws {
        let (store, _) = try fixture()
        let app = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: app.path))
        let result = store.importPins(from: [app])
        XCTAssertEqual(result.launchItems, 1)
        XCTAssertTrue(store.folders.isEmpty)
        XCTAssertEqual(store.launchItems.first?.kind, .application)
    }
}
