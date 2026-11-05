import Combine
import Foundation

@MainActor
final class FileMatrixScanner: ObservableObject {
    struct Node: Identifiable, Hashable, Sendable {
        let url: URL
        let name: String
        let size: Int64
        let isDirectory: Bool

        var id: URL { url }
    }

    struct Snapshot: Sendable {
        let nodes: [Node]
        let totalSize: Int64
        let errorDescription: String?
    }

    @Published private(set) var nodes: [Node] = []
    @Published private(set) var totalSize: Int64 = 0
    @Published private(set) var currentURL: URL?
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0
    @Published private(set) var errorText: String?
    @Published private(set) var hasScanned = false
    @Published private(set) var wasCancelled = false

    nonisolated static let maxNodes = 30
    nonisolated private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .fileSizeKey
    ]

    private let rootURL: URL
    private var history: [URL] = []
    private var cache: [URL: Snapshot] = [:]
    private var worker: Task<Snapshot, Never>?
    private var progressTimer: Timer?
    private var progress = ScanCounter()
    private var generation = UUID()

    init(rootURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.rootURL = rootURL
    }

    var canGoBack: Bool {
        !history.isEmpty
    }

    var currentName: String {
        guard let currentURL, currentURL.path != rootURL.path else {
            return "主目录"
        }
        return currentURL.lastPathComponent
    }

    var displayPath: String {
        guard let currentURL else {
            return "主目录"
        }
        let home = rootURL.path
        let path = currentURL.path
        if path == home {
            return "主目录"
        }
        if path.hasPrefix(home + "/") {
            return "主目录 / " + path.dropFirst(home.count + 1)
        }
        return path
    }

    func prepareRoot() {
        guard !isScanning else {
            return
        }
        if currentURL == nil {
            currentURL = rootURL
            history = []
        }
    }

    func open(_ node: Node) {
        guard node.isDirectory, node.url != currentURL else {
            return
        }
        if let currentURL {
            history.append(currentURL)
        }
        navigate(to: node.url)
    }

    func goBack() {
        guard let previous = history.popLast() else {
            return
        }
        navigate(to: previous)
    }

    func refresh() {
        if currentURL == nil {
            currentURL = rootURL
            history = []
        }
        guard let currentURL else {
            return
        }
        cache[currentURL] = nil
        startScan(currentURL)
    }

    func cancel() {
        worker?.cancel()
        worker = nil
        progressTimer?.invalidate()
        progressTimer = nil
        generation = UUID()
        isScanning = false
        scannedCount = 0
        wasCancelled = true
    }

    func remove(_ url: URL) {
        guard let node = nodes.first(where: { $0.url == url }) else {
            return
        }
        nodes.removeAll { $0.url == url }
        totalSize = max(0, totalSize - node.size)
        cache.removeAll()
    }

    private func navigate(to url: URL) {
        worker?.cancel()
        worker = nil
        progressTimer?.invalidate()
        progressTimer = nil
        generation = UUID()
        currentURL = url
        errorText = nil
        isScanning = false
        wasCancelled = false

        if let snapshot = cache[url] {
            apply(snapshot)
            return
        }
        startScan(url)
    }

    private func startScan(_ url: URL) {
        worker?.cancel()
        generation = UUID()
        let generation = generation
        progress = ScanCounter()
        scannedCount = 0
        nodes = []
        totalSize = 0
        errorText = nil
        isScanning = true
        wasCancelled = false
        hasScanned = true

        let progress = self.progress
        let task = Task.detached(priority: .utility) {
            Self.scanChildren(of: url, progress: progress)
        }
        worker = task

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
            let snapshot = await task.value
            guard !task.isCancelled, let self,
                  self.generation == generation,
                  self.currentURL == url else {
                return
            }
            self.finish(url: url, snapshot: snapshot)
        }
    }

    private func finish(url: URL, snapshot: Snapshot) {
        worker = nil
        progressTimer?.invalidate()
        progressTimer = nil
        isScanning = false
        scannedCount = progress.count
        cache[url] = snapshot
        if currentURL == url {
            apply(snapshot)
        }
    }

    private func apply(_ snapshot: Snapshot) {
        nodes = snapshot.nodes
        totalSize = snapshot.totalSize
        errorText = snapshot.errorDescription
        isScanning = false
    }

    private nonisolated static func scanChildren(
        of directory: URL,
        progress: ScanCounter
    ) -> Snapshot {
        let fileManager = FileManager.default
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
        } catch {
            return Snapshot(nodes: [], totalSize: 0, errorDescription: readErrorText(error))
        }

        var nodes: [Node] = []
        var total: Int64 = 0
        for child in children {
            if Task.isCancelled {
                break
            }
            guard let values = try? child.resourceValues(forKeys: resourceKeys),
                  values.isSymbolicLink != true else {
                continue
            }
            let isDirectory = values.isDirectory == true
            let size: Int64
            if isDirectory {
                size = directorySize(of: child, progress: progress)
            } else {
                progress.increment()
                size = Int64(values.fileSize ?? 0)
            }
            guard size > 0 else {
                continue
            }
            nodes.append(
                Node(
                    url: child,
                    name: child.lastPathComponent,
                    size: size,
                    isDirectory: isDirectory
                )
            )
            total += size
        }

        nodes.sort { $0.size > $1.size }
        if nodes.count > maxNodes {
            nodes = Array(nodes.prefix(maxNodes))
        }
        return Snapshot(nodes: nodes, totalSize: total, errorDescription: nil)
    }

    private nonisolated static func directorySize(
        of directory: URL,
        progress: ScanCounter
    ) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            if Task.isCancelled {
                break
            }
            progress.increment()
            guard let values = try? url.resourceValues(forKeys: resourceKeys),
                  values.isSymbolicLink != true,
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private nonisolated static func readErrorText(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileReadNoPermissionError {
            return "没有权限读取此文件夹"
        }
        return "无法读取此文件夹：\(error.localizedDescription)"
    }
}

private final class ScanCounter: @unchecked Sendable {
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
