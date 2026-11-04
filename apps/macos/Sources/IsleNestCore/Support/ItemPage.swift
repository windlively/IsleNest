import Foundation

/// Keeps the visible items and keyboard navigation on the same, valid page.
public struct ItemPage<Element> {
    public let items: [Element]
    public let index: Int
    public let count: Int

    public init(_ allItems: [Element], index: Int, size: Int = 4) {
        let size = max(1, size)
        count = max(1, (allItems.count + size - 1) / size)
        self.index = min(max(0, index), count - 1)
        items = Array(allItems.dropFirst(self.index * size).prefix(size))
    }
}
