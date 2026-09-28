import Combine
import Foundation

/// Popular videos: loads pages as the user scrolls and recovers when the connection returns.
///
/// New filters load popular videos again from the first page. The videos on screen stay, dimmed, until the
/// new ones arrive.
final class VideoFeedViewModel: ObservableObject {
    @Published private(set) var pages = Paginator<Video>()
    /// Set when the shown videos are an offline copy.
    @Published private(set) var savedAt: Date?
    @Published private(set) var filters = VideoFilters()
    /// True while videos for new filters replace the ones on screen.
    @Published private(set) var isReplacingVideos = false

    var videos: [Video] { pages.items }

    private let repository: any VideoRepository
    private var subscriptions = Set<AnyCancellable>()
    /// Changes when the list is replaced, so pages requested for the old list are dropped.
    private var generation = 0
    private var firstLoad: Task<Void, Never>?

    /// Without `onlineUpdates` the videos still load, but do not reload when the connection returns.
    init(repository: any VideoRepository, onlineUpdates: AnyPublisher<Bool, Never> = Empty().eraseToAnyPublisher()) {
        self.repository = repository
        onlineUpdates
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in self?.retryAfterReconnect() }
            .store(in: &subscriptions)
    }

    /// Later calls do nothing, so returning to the tab keeps its place.
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

    /// Does nothing while new filters replace the videos: the old videos belong to the old filters.
    func loadMoreIfNeeded(after video: Video) async {
        guard !isReplacingVideos, pages.isNearEnd(video.id), !pages.phase.isFailed else { return }
        await loadNextPage()
    }

    func retry() async {
        guard !isReplacingVideos else { return }
        await loadNextPage()
    }

    /// Keeps the current videos on screen until the fresh first page arrives.
    func refresh() async {
        let current = generation
        var fresh = pages.restarted()
        guard let page = fresh.beginNextPage() else { return }
        do {
            let result = try await repository.popularVideos(filters: filters, page: page)
            guard current == generation else { return }
            // The saved copy is never newer than the list on screen, and it is only the first page,
            // so offline the list stays as it is.
            if result.savedAt != nil, !pages.isEmpty { return }
            fresh.completePage(with: result.videos, hasMore: result.hasMore)
            generation += 1
            pages = fresh
            // A filter change still loading is dropped by the new generation, so it cannot end the dimming.
            isReplacingVideos = false
            savedAt = result.savedAt
        } catch let error as NetworkError {
            guard current == generation else { return }
            // An empty list that is loading has its own request, which reports how it ends.
            if pages.isEmpty, pages.phase != .loading { pages.failPage(with: error) }
        } catch {}
    }

    /// Loads popular videos again for `newFilters`. Unlike a refresh, a failure replaces the old videos,
    /// which no longer match what the user asked for.
    func applyFilters(_ newFilters: VideoFilters) async {
        guard newFilters != filters else { return }
        filters = newFilters
        generation += 1
        let current = generation
        var fresh = pages.restarted()
        guard let page = fresh.beginNextPage() else { return }
        isReplacingVideos = !pages.isEmpty
        if pages.isEmpty { pages = fresh }
        do {
            let result = try await repository.popularVideos(filters: newFilters, page: page)
            guard current == generation else { return }
            fresh.completePage(with: result.videos, hasMore: result.hasMore)
            savedAt = result.savedAt
        } catch is CancellationError {
            guard current == generation else { return }
            fresh.cancelPage()
        } catch {
            guard current == generation else { return }
            fresh.failPage(with: error as? NetworkError ?? .invalidResponse)
        }
        pages = fresh
        isReplacingVideos = false
    }

    private func loadNextPage() async {
        let current = generation
        let filters = filters
        guard let page = pages.beginNextPage() else { return }
        do {
            let result = try await repository.popularVideos(filters: filters, page: page)
            guard current == generation else { return }
            pages.completePage(with: result.videos, hasMore: result.hasMore)
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
