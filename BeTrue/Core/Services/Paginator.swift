import Foundation

/// One page in flight at a time; drops items already seen on earlier pages.
nonisolated struct Paginator<Item: Identifiable & Sendable>: Sendable where Item.ID: Sendable {
    enum Phase: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(NetworkError)
        case finished

        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    private enum Constants {
        static var firstPage: Int { 1 }
        /// A page and a half of 80, so a run of fast flings stays inside what is loaded.
        static var lookahead: Int { 120 }
    }

    /// How many items past the one on screen should already be loaded.
    let lookahead: Int
    private(set) var items: [Item] = []
    private(set) var phase = Phase.idle

    var isEmpty: Bool { items.isEmpty }

    private var nextPage = Constants.firstPage
    /// Each item's index in `items`; also how items seen on an earlier page are dropped.
    private var positions: [Item.ID: Int] = [:]

    init(lookahead: Int = Constants.lookahead) {
        self.lookahead = lookahead
    }

    /// Returns nil while a page is loading or after the last page.
    mutating func beginNextPage() -> Int? {
        switch phase {
        case .loading, .finished: return nil
        case .idle, .loaded, .failed: break
        }
        phase = .loading
        return nextPage
    }

    mutating func completePage(with newItems: [Item], hasMore: Bool) {
        for item in newItems where positions[item.id] == nil {
            positions[item.id] = items.count
            items.append(item)
        }
        nextPage += 1
        phase = hasMore && !newItems.isEmpty ? .loaded : .finished
    }

    mutating func failPage(with error: NetworkError) {
        phase = .failed(error)
    }

    /// Releases a page whose request was cancelled, so the same page can be claimed again.
    mutating func cancelPage() {
        guard phase == .loading else { return }
        phase = items.isEmpty ? .idle : .loaded
    }

    /// An empty list with the same lookahead, for a list that starts over.
    func restarted() -> Self {
        Self(lookahead: lookahead)
    }

    func position(of id: Item.ID) -> Int? {
        positions[id]
    }

    func isNearEnd(_ id: Item.ID) -> Bool {
        guard let position = positions[id] else { return false }
        return position >= items.count - lookahead
    }
}
