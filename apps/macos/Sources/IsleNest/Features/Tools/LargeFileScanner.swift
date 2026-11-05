import Foundation

@MainActor
final class LargeFileScanner: ObservableObject {
    struct LargeFile: Identifiable, Hashable, Sendable {
        let url: URL
        let size: Int64

        var id: URL { url }
    }

    nonisolated static let threshold: Int64 = 50 * 1_000_000
    nonisolated static let maxResults = 20

    @Published private(set) var files: [LargeFile] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var scanRoot: URL?

    private var workerTask: Task<[LargeFile], Never>?
    private var progressTimer: Timer?
    private var progress = ScanProgress()
    private var scanGeneration = UUID()

    func toggle(root: URL? = nil) {
        if isScanning {
            cancel()
        } else {
            start(root: root)
        }
    }

    func start(root: URL? = nil) {
        cancel()
        let root = root ?? FileManager.default.homeDirectoryForCurrentUser
        files = []
        scannedCount = 0
        scanRoot = root
        isScanning = true
        progress = ScanProgress()
        let generation = UUID()
        scanGeneration = generation

        let progress = self.progress
        workerTask = Task.detached(priority: .utility) {
            Self.scan(root: root, threshold: Self.threshold, progress: progress)
        }

        progressTimer?.invalidate()
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isScanning else {
                    return
                }
                self.scannedCount = self.progress.count
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer

        Task { [weak self] in
            guard let self, let workerTask = self.workerTask else {
                return
            }
            let result = await workerTask.value
            guard !workerTask.isCancelled,
                  self.scanGeneration == generation else {
                return
            }
            self.finish(with: result)
        }
    }

    func cancel() {
        scanGeneration = UUID()
        workerTask?.cancel()
        workerTask = nil
        progressTimer?.invalidate()
        progressTimer = nil
        isScanning = false
    }

    func remove(_ url: URL) {
        files.removeAll { $0.url == url }
    }

    private func finish(with result: [LargeFile]) {
        workerTask = nil
        progressTimer?.invalidate()
        progressTimer = nil
        isScanning = false
        scannedCount = progress.count
        files = result
        lastScanDate = Date()
    }

    private nonisolated static func scan(
        root: URL,
        threshold: Int64,
        progress: ScanProgress
    ) -> [LargeFile] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        let libraryPath = root.appendingPathComponent("Library").path + "/"
        var found: [LargeFile] = []

        for case let url as URL in enumerator {
            if Task.isCancelled {
                break
            }
            progress.increment()
            if url.path.hasPrefix(libraryPath) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let size = values.fileSize,
                  size >= threshold else {
                continue
            }
            found.append(LargeFile(url: url, size: Int64(size)))
        }

        found.sort { $0.size > $1.size }
        return Array(found.prefix(maxResults))
    }
}

private final class ScanProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
