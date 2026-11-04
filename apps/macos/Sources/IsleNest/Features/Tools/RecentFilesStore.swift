import Combine
import Foundation

@MainActor
final class RecentFilesStore: ObservableObject {
    struct RecentFile: Identifiable, Hashable {
        let url: URL
        let lastUsed: Date?

        var id: URL { url }
        var name: String { url.lastPathComponent }
        var folderName: String { url.deletingLastPathComponent().lastPathComponent }
    }

    @Published private(set) var files: [RecentFile] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    private var query: NSMetadataQuery?
    private var cancellables: Set<AnyCancellable> = []
    private var timeoutTask: Task<Void, Never>?
    private var lastLoadDate: Date?

    private static let maxFiles = 12
    private static let cacheLifetime: TimeInterval = 60

    func load(force: Bool = false) {
        if isLoading, !force {
            return
        }
        if !force,
           let lastLoadDate,
           Date().timeIntervalSince(lastLoadDate) < Self.cacheLifetime {
            return
        }

        cancelQuery()
        isLoading = true

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.predicate = NSPredicate(
            format: "%K >= %@",
            NSMetadataItemLastUsedDateKey,
            Calendar.current.date(byAdding: .day, value: -30, to: Date())! as NSDate
        )
        query.notificationBatchingInterval = 0.2
        self.query = query

        NotificationCenter.default.publisher(
            for: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.finish(with: query)
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: .NSMetadataQueryDidUpdate,
            object: query
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.finish(with: query)
        }
        .store(in: &cancellables)

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.finish(with: query)
        }

        query.start()
    }

    private func finish(with query: NSMetadataQuery) {
        guard query === self.query else {
            return
        }
        timeoutTask?.cancel()
        timeoutTask = nil
        query.disableUpdates()
        query.stop()

        let home = NSHomeDirectory()
        var seen: Set<String> = []
        var collected: [RecentFile] = []

        for case let item as NSMetadataItem in query.results {
            guard let rawPath = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
                continue
            }
            let url = URL(fileURLWithPath: rawPath)
            let path = url.standardizedFileURL.path
            let relativeComponents = path
                .dropFirst(home.count + 1)
                .split(separator: "/")
            guard !path.hasPrefix(home + "/Library/"),
                  !path.hasPrefix(home + "/.Trash/"),
                  !relativeComponents.contains(where: { $0.hasPrefix(".") }),
                  !seen.contains(path) else {
                continue
            }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                continue
            }
            seen.insert(path)
            let lastUsed = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
                ?? item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
            collected.append(RecentFile(url: url, lastUsed: lastUsed))
        }

        collected.sort {
            ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast)
        }
        files = Array(collected.prefix(Self.maxFiles))
        isLoading = false
        hasLoaded = true
        lastLoadDate = Date()
        self.query = nil
        DispatchQueue.main.async { [weak self] in
            guard let self, self.query == nil else {
                return
            }
            self.cancellables.removeAll()
        }
    }

    private func cancelQuery() {
        timeoutTask?.cancel()
        timeoutTask = nil
        cancellables.removeAll()
        query?.disableUpdates()
        query?.stop()
        query = nil
    }
}
