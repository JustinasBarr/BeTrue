import Combine
import Foundation

/// Once the user stops scrolling, keeps the first page's pictures on the device so the list shows them offline.
/// An `ObservableObject` only so a grid can hold it as a `@StateObject`; it publishes nothing.
final class OfflineImageKeeper: ObservableObject {
    private enum Constants {
        /// One page, the part of each list the repositories keep offline.
        static let keptCount = 80
        /// How long the list stays still before its pictures are saved.
        static let idleDelay: Duration = .seconds(2)
    }

    private var pending: Task<Void, Never>?

    deinit {
        pending?.cancel()
    }

    /// Starts the wait again; when it ends, keeps the images of the first items of `items`.
    func scrolled<Item>(through items: [Item], imageURL: KeyPath<Item, URL>, loader: any ImageLoading) {
        pending?.cancel()
        let kept = items.prefix(Constants.keptCount)
        pending = Task(priority: .utility) {
            try? await Task.sleep(for: Constants.idleDelay)
            guard !Task.isCancelled else { return }
            await loader.keepOffline(kept.map { $0[keyPath: imageURL] })
        }
    }
}
