import Combine
import Foundation

/// Photo search as the user types. Searches when typing pauses; an empty field returns to curated photos.
/// A newer search always wins and old results stay dimmed until it lands. Only committed searches are
/// remembered. Filters last the session.
final class PhotoSearchViewModel: ObservableObject {
    private enum Constants {
        static let recentSearchesKey = "recentSearches"
        static let recentSearchesLimit = 8
        static let typingPause = Duration.milliseconds(300)
        /// Shorter than the feed's: every page counts against the hourly rate limit.
        static let resultsLookahead = 60
    }

    @Published var query = ""
    @Published private(set) var submittedQuery = ""
    /// Used by the next search.
    @Published private(set) var filters = SearchFilters()
    /// The filters of the results on screen.
    @Published private(set) var submittedFilters = SearchFilters()
    @Published private(set) var results = Paginator<Photo>(lookahead: Constants.resultsLookahead)
    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var isReplacingResults = false
    @Published private(set) var savedAt: Date?

    var photos: [Photo] { results.items }
    var isShowingResults: Bool { !submittedQuery.isEmpty }

    private let repository: any PhotoRepository
    private let store: any LocalStoring
    private let typingPause: Duration
    private var generation = 0
    private var pendingSearch: Task<Void, Never>?
    /// Chains writes so an older list never lands after a newer one.
    private var pendingSave: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(repository: any PhotoRepository, store: any LocalStoring, typingPause: Duration = Constants.typingPause) {
        self.repository = repository
        self.store = store
        self.typingPause = typingPause
        $query
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] text in self?.scheduleSearch(for: text) }
            .store(in: &subscriptions)
    }

    func loadRecentSearches() async {
        guard let saved = await store.savedData(forKey: Constants.recentSearchesKey),
              let searches = try? JSONDecoder().decode([String].self, from: saved.data) else { return }
        recentSearches = searches
    }

    func submitSearch() async {
        await search(for: query)
    }

    func search(for text: String) async {
        let trimmed = Self.trimmed(text)
        guard !trimmed.isEmpty else { return }
        let isAlreadyShown = trimmed == submittedQuery && filters == submittedFilters && !results.isEmpty
        query = trimmed
        // Setting the query schedules a delayed search; this one runs now instead.
        pendingSearch?.cancel()
        if isAlreadyShown {
            await rememberSearch(trimmed)
        } else {
            await runSearch(trimmed, remembering: true)
        }
    }

    func applyFilters(_ newFilters: SearchFilters) async {
        guard newFilters != filters else { return }
        filters = newFilters
        let text = Self.trimmed(query)
        guard !text.isEmpty else { return }
        pendingSearch?.cancel()
        await runSearch(text, remembering: false)
    }

    func refresh() async {
        guard isShowingResults else { return }
        await runSearch(submittedQuery, remembering: false)
    }

    /// Skipped while a new search replaces the results: the old photos belong to the old query.
    func loadMoreIfNeeded(after photo: Photo) async {
        guard !isReplacingResults, results.isNearEnd(photo.id), !results.phase.isFailed else { return }
        await loadNextPage()
    }

    func retry() async {
        guard !isReplacingResults else { return }
        if results.isEmpty {
            await runSearch(submittedQuery, remembering: false)
        } else {
            await loadNextPage()
        }
    }

    func cancelSearch() {
        query = ""
        clearResults()
    }

    func removeRecentSearch(_ text: String) async {
        recentSearches.removeAll { $0 == text }
        await saveRecentSearches()
    }

    private func runSearch(_ text: String, remembering: Bool) async {
        let filters = filters
        submittedQuery = text
        submittedFilters = filters
        generation += 1
        let current = generation
        var fresh = results.restarted()
        guard let page = fresh.beginNextPage() else { return }
        isReplacingResults = !results.isEmpty
        if results.isEmpty { results = fresh }
        if remembering { await rememberSearch(text) }
        do {
            let result = try await repository.searchPhotos(matching: text, filters: filters, page: page)
            guard current == generation else { return }
            fresh.completePage(with: result.photos, hasMore: result.hasMore)
            savedAt = result.savedAt
        } catch is CancellationError {
            guard current == generation else { return }
            fresh.cancelPage()
        } catch {
            guard current == generation else { return }
            fresh.failPage(with: error as? NetworkError ?? .invalidResponse)
        }
        results = fresh
        isReplacingResults = false
    }

    private func scheduleSearch(for text: String) {
        pendingSearch?.cancel()
        let trimmed = Self.trimmed(text)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }
        guard trimmed != submittedQuery else { return }
        pendingSearch = Task { [weak self, typingPause] in
            try? await Task.sleep(for: typingPause)
            // A tapped recent search may have started this same search while it waited.
            guard !Task.isCancelled, let self, trimmed != submittedQuery else { return }
            // Unstructured so later typing cancels only the pause; the screen never empties in between.
            await Task { await self.runSearch(trimmed, remembering: false) }.value
        }
    }

    private func clearResults() {
        pendingSearch?.cancel()
        generation += 1
        submittedQuery = ""
        results = results.restarted()
        isReplacingResults = false
        savedAt = nil
    }

    private func loadNextPage() async {
        let current = generation
        let text = submittedQuery
        let filters = submittedFilters
        guard !text.isEmpty, let page = results.beginNextPage() else { return }
        do {
            let result = try await repository.searchPhotos(matching: text, filters: filters, page: page)
            guard current == generation else { return }
            results.completePage(with: result.photos, hasMore: result.hasMore)
        } catch is CancellationError {
            guard current == generation else { return }
            results.cancelPage()
        } catch {
            guard current == generation else { return }
            results.failPage(with: error as? NetworkError ?? .invalidResponse)
        }
    }

    private func rememberSearch(_ text: String) async {
        recentSearches.removeAll { $0.caseInsensitiveCompare(text) == .orderedSame }
        recentSearches.insert(text, at: 0)
        recentSearches = Array(recentSearches.prefix(Constants.recentSearchesLimit))
        await saveRecentSearches()
    }

    private func saveRecentSearches() async {
        guard let data = try? JSONEncoder().encode(recentSearches) else { return }
        let previous = pendingSave
        let save = Task { [store] in
            await previous?.value
            await store.save(data, forKey: Constants.recentSearchesKey)
        }
        pendingSave = save
        await save.value
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
