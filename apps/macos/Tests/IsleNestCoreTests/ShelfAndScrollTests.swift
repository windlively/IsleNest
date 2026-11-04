import CoreGraphics
import XCTest
@testable import IsleNestCore

@MainActor
final class ShelfTests: XCTestCase {
    private func makeBacking() -> (store: ConfigStore, defaults: UserDefaults, key: String) {
        let suiteName = "islenest.shelf.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (ConfigStore(defaults: defaults, stateKey: "state"), defaults, "state")
    }

    private func makeTempFile(named name: String = "note.txt") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("islenest-shelf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data("hello".utf8).write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return url
    }

    func testAddsFilesAndDeduplicates() throws {
        let store = makeBacking().store
        let url = try makeTempFile()

        let first = store.addShelfItems(at: [url])
        XCTAssertEqual(first.added, 1)
        XCTAssertEqual(store.shelfItems.count, 1)
        XCTAssertEqual(store.shelfItems[0].title, "note.txt")

        let second = store.addShelfItems(at: [url])
        XCTAssertEqual(second.duplicates, 1)
        XCTAssertEqual(store.shelfItems.count, 1)
    }

    func testRejectsNonFileURLsAndEnforcesLimit() throws {
        let store = makeBacking().store
        XCTAssertEqual(store.addShelfItems(at: [URL(string: "https://example.com")!]).rejected, 1)

        for index in 0..<ConfigStore.maxShelfItemCount {
            let url = try makeTempFile(named: "file-\(index).txt")
            XCTAssertEqual(store.addShelfItems(at: [url]).added, 1)
        }
        let overflow = store.addShelfItems(at: [try makeTempFile(named: "extra.txt")])
        XCTAssertTrue(overflow.limitReached)
        XCTAssertEqual(store.shelfItems.count, ConfigStore.maxShelfItemCount)
    }

    func testPersistsRemovesAndClears() throws {
        let backing = makeBacking()
        let url = try makeTempFile()
        backing.store.addShelfItems(at: [url])
        let id = backing.store.shelfItems[0].id

        let reloaded = ConfigStore(defaults: backing.defaults, stateKey: backing.key)
        XCTAssertEqual(reloaded.shelfItems.count, 1)
        XCTAssertEqual(reloaded.resolveShelfItem(id: id)?.lastPathComponent, "note.txt")

        reloaded.removeShelfItem(id: id)
        XCTAssertTrue(reloaded.shelfItems.isEmpty)

        reloaded.addShelfItems(at: [url])
        reloaded.clearShelf()
        XCTAssertTrue(reloaded.shelfItems.isEmpty)
    }
}

final class ScrollStitcherTests: XCTestCase {
    private let width = 64

    private func makeSource(height: Int) -> CGImage {
        var data = [UInt8]()
        data.reserveCapacity(width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                data.append(UInt8((row * 3 + column) % 251))
                data.append(UInt8((row * 7) % 253))
                data.append(UInt8((row &+ column &* 11) % 249))
                data.append(255)
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private func crop(_ image: CGImage, from row: Int, height: Int) -> CGImage {
        image.cropping(to: CGRect(x: 0, y: row, width: image.width, height: height))!
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let offset = (y * image.width + x) * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
    }

    func testStitchesOverlappingFramesInOrder() {
        let source = makeSource(height: 500)
        let stitcher = ScrollStitcher()

        XCTAssertEqual(stitcher.append(crop(source, from: 0, height: 200)), .started)
        XCTAssertEqual(stitcher.append(crop(source, from: 150, height: 200)), .appended(addedHeight: 150))
        XCTAssertEqual(stitcher.append(crop(source, from: 300, height: 200)), .appended(addedHeight: 150))

        let image = stitcher.image!
        XCTAssertEqual(image.width, width)
        XCTAssertEqual(image.height, 500)
        XCTAssertEqual(stitcher.appendedFrames, 3)

        for row in [0, 149, 200, 349, 499] {
            XCTAssertEqual(pixel(image, x: 13, y: row).0, pixel(source, x: 13, y: row).0, "row \(row)")
            XCTAssertEqual(pixel(image, x: 13, y: row).1, pixel(source, x: 13, y: row).1, "row \(row)")
            XCTAssertEqual(pixel(image, x: 13, y: row).2, pixel(source, x: 13, y: row).2, "row \(row)")
        }
    }

    func testDetectsDuplicateFrameAndRejectsUnrelatedFrame() {
        let source = makeSource(height: 300)
        let stitcher = ScrollStitcher()
        let frame = crop(source, from: 0, height: 200)
        XCTAssertEqual(stitcher.append(frame), .started)
        XCTAssertEqual(stitcher.append(frame), .duplicate)
        XCTAssertEqual(stitcher.image?.height, 200)

        let unrelated = makeSolidImage(width: width, height: 200, value: 255)
        XCTAssertEqual(stitcher.append(unrelated), .noMatch)
        XCTAssertEqual(stitcher.image?.height, 200)
    }

    private func makeSolidImage(width: Int, height: Int, value: UInt8) -> CGImage {
        var data = [UInt8]()
        for _ in 0..<(width * height) {
            data.append(contentsOf: [value, value, value, 255])
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
