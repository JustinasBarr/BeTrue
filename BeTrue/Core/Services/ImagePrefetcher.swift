import Combine
import Foundation

/// Loads the images just below the screen, nearest first, below the priority of the tiles on screen.
/// An `ObservableObject` only so a grid can hold it as a `@StateObject`; it publishes nothing.
final class ImagePrefetcher: ObservableObject {
    private enum Constants {
        /// About three screens of two-column tiles.
        static let lookahead = 24
        /// Leaves most of the connection to the tiles on screen.
        static let maxConcurrentLoads = 4
    }

    /// The furthest position shown since the window last started.
    private var furthest = -1
    /// Every position up to here has been queued or skipped.
    private var queuedThrough = -1
    /// Nearest first.
    private var waiting: [(position: Int, request: ImageRequest)] = []
    private var runningLoads = 0
    /// Changes when the window starts over, so loads for an old list do not free a slot in the new one.
    private var generation = 0

    /// Records that `position` is on screen and loads the images after it. `request` returns nil to skip one.
    func itemAppeared(at position: Int,
                      count: Int,
                      loader: any ImageLoading,
                      request: (Int) -> ImageRequest?) {
        if position < furthest - Constants.lookahead {
            startOver()
        }
        furthest = max(furthest, position)
        waiting.removeAll { $0.position <= furthest }
        let end = min(furthest + Constants.lookahead, count - 1)
        var next = max(queuedThrough, furthest) + 1
        while next <= end {
            if let image = request(next), loader.cachedImage(for: image.url, maxPixelSize: image.maxPixelSize) == nil {
                waiting.append((next, image))
            }
            next += 1
        }
        queuedThrough = max(queuedThrough, end)
        startLoads(with: loader)
    }

    /// Forgets the window, for a list that was replaced and reuses positions for other items.
    func startOver() {
        generation += 1
        furthest = -1
        queuedThrough = -1
        waiting.removeAll()
        runningLoads = 0
    }

    private func startLoads(with loader: any ImageLoading) {
        while runningLoads < Constants.maxConcurrentLoads, !waiting.isEmpty {
            let image = waiting.removeFirst().request
            let current = generation
            runningLoads += 1
            Task(priority: .utility) { [weak self] in
                _ = await loader.image(for: image.url, maxPixelSize: image.maxPixelSize)
                guard let self, current == generation else { return }
                runningLoads -= 1
                startLoads(with: loader)
            }
        }
    }
}
