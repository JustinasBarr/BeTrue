import Combine
import Foundation

/// The curated feed: loads pages as the user scrolls and recovers when the connection returns.
final class PhotoFeedViewModel: ObservableObject {
    @Published private(set) var pages = Paginator<Photo>()
    /// When the shown photos were saved on the device, if they are an offline copy.
    @Published private(set) var savedAt: Date?

    var photos: [Photo] { pages.items }

    private let repository: any PhotoRepository
    private var subscriptions = Set<AnyCancellable>()
    /// Changes when refresh replaces the list, so pages requested for the old list are dropped.
    private var generation = 0
    private var firstLoad: Task<Void, Never>?

    init(repository: any PhotoRepository, onlineUpdates: AnyPublisher<Bool, Never>) {
        self.repository = repository
        onlineUpdates
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in self?.retryAfterReconnect() }
            .store(in: &subscriptions)
    }

    /// Loads the first page once; later calls do nothing, so returning to the feed keeps its place.
    func loadFirstPage() async {
        if firstLoad == nil {
            guard pages.isEmpty, pages.phase == .idle else { return }
            // The model owns this load rather than the screen's task: the paged tab view cancels a page's
            // tasks as it swipes past, which would leave the page loading forever.
            firstLoad = Task {
                await loadNextPage()
                // Cleared once it ends, so a load cancelled before its page arrived can start again.
                firstLoad = nil
            }
        }
        // A call made before the load has started waits for it rather than asking for a page of its own.
        await firstLoad?.value
    }

    /// Starts the next page when `photo` is close to the end of what is loaded.
    func loadMoreIfNeeded(after photo: Photo) async {
        guard pages.isNearEnd(photo.id) else { return }
        if case .failed = pages.phase { return }
        await loadNextPage()
    }

    /// Tries the failed page again.
    func retry() async {
        await loadNextPage()
    }

    /// Replaces everything with a fresh first page, for pull to refresh.
    func refresh() async {
        var fresh = pages.restarted()
        guard let page = fresh.beginNextPage() else { return }
        do {
            let result = try await repository.curatedPhotos(page: page)
            // The saved copy is never newer than the list on screen, and it is only the first page,
            // so offline the list stays as it is.
            if result.savedAt != nil, !pages.isEmpty { return }
            fresh.completePage(with: result.photos, hasMore: result.hasMore)
            generation += 1
            pages = fresh
            savedAt = result.savedAt
        } catch let error as NetworkError {
            // An empty list that is loading has its own request, which reports how it ends.
            if pages.isEmpty, pages.phase != .loading { pages.failPage(with: error) }
        } catch {}
    }

    private func loadNextPage() async {
        let current = generation
        guard let page = pages.beginNextPage() else { return }
        do {
            let result = try await repository.curatedPhotos(page: page)
            guard current == generation else { return }
            pages.completePage(with: result.photos, hasMore: result.hasMore)
            if page == 1 || result.savedAt != nil { savedAt = result.savedAt }
        } catch is CancellationError {
            guard current == generation else { return }
            pages.cancelPage()
        } catch {
            guard current == generation else { return }
            pages.failPage(with: error as? NetworkError ?? .invalidResponse)
        }
    }

    private func retryAfterReconnect() {
        guard savedAt != nil || pages.phase.isFailed else { return }
        Task {
            if pages.phase.isFailed { await retry() } else { await refresh() }
        }
    }
}
