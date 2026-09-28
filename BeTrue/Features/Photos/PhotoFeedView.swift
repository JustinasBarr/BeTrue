import Combine
import SwiftUI

/// Curated photos in one grid that search results replace as the user types. The pinned header hides
/// on scroll down and returns on a longer scroll up.
struct PhotoFeedView: View {
    private enum Constants {
        static let coordinateSpace = "photosScroll"
        static let topID = "photosTop"
        static let headerTopPadding: CGFloat = 8
        static let headerBottomPadding: CGFloat = 12
        static let headerSpacing: CGFloat = 12
        /// How much of the previous photos shows while a new search loads.
        static let replacingOpacity = 0.4
        /// Nonisolated because the alignment guide reads it from a Sendable closure.
        nonisolated static let completionsGap: CGFloat = 8
    }

    /// Changes each time the open Photos tab is tapped again.
    let scrollToTopRequest: Int
    let headerChrome: ScrollChrome.Header
    let onScroll: (CGFloat) -> Void

    @StateObject private var feed: PhotoFeedViewModel
    @StateObject private var search: PhotoSearchViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var completer = SearchCompleter()
    @State private var coveredTop = ViewerCoveredTop()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    init(repository: any PhotoRepository,
         store: any LocalStoring,
         onlineUpdates: AnyPublisher<Bool, Never>,
         scrollToTopRequest: Int,
         headerChrome: ScrollChrome.Header,
         onScroll: @escaping (CGFloat) -> Void) {
        _feed = StateObject(wrappedValue: PhotoFeedViewModel(repository: repository, onlineUpdates: onlineUpdates))
        _search = StateObject(wrappedValue: PhotoSearchViewModel(repository: repository, store: store))
        self.scrollToTopRequest = scrollToTopRequest
        self.headerChrome = headerChrome
        self.onScroll = onScroll
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ScrollOffsetMarkerView(coordinateSpace: Constants.coordinateSpace)
                        .id(Constants.topID)
                    grid
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onScrollOffsetChange(coordinateSpace: Constants.coordinateSpace, perform: onScroll)
            .refreshable { await refresh() }
            .environment(\.viewerCoveredTop, coveredTop)
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .scrollChromeHeader(isShown: isHeaderShown, spring: headerChrome.spring)
                    .background { coveredTopReader }
            }
            .onChange(of: scrollToTopRequest) { _ in
                withAnimation(Motion.respecting(reduceMotion: reduceMotion, Motion.hero)) {
                    proxy.scrollTo(Constants.topID, anchor: .top)
                }
            }
            .onChange(of: search.submittedQuery) { _ in
                proxy.scrollTo(Constants.topID, anchor: .top)
            }
            .onChange(of: search.submittedFilters) { _ in
                proxy.scrollTo(Constants.topID, anchor: .top)
            }
        }
        .background(Palette.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await feed.loadFirstPage() }
        .task { await search.loadRecentSearches() }
        .onChange(of: isSearchFocused) { isFocused in
            if isFocused { rebuildCompleter() }
        }
        .onChange(of: search.results.items.count) { _ in
            if isSearchFocused { rebuildCompleter() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Constants.headerSpacing) {
            ScreenHeaderView(title: "Photos")
            SearchFieldView(text: $search.query,
                            prompt: "Search photos",
                            isFocused: $isSearchFocused,
                            isActive: search.isShowingResults,
                            onSubmit: submit,
                            onCancel: search.cancelSearch)
                .overlay(alignment: .bottom) {
                    completionList
                        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.dropdown),
                                   value: completions.isEmpty)
                }
                // Above the filter row, which the completions cover.
                .zIndex(1)
            if showsFilters {
                SearchFilterBarView(filters: search.filters, onChange: applyFilters)
                    .transition(.opacity)
            }
            if showsTerms {
                SearchTermsView(recentSearches: search.recentSearches, onChoose: choose, onRemove: remove)
                    .transition(.opacity)
            }
            if let savedAt {
                SavedCopyBannerView(savedAt: savedAt)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, Constants.headerTopPadding)
        .padding(.bottom, Constants.headerBottomPadding)
        // Under the header's content, so the completions pass over it.
        .background(alignment: .bottom) {
            searchLoadingLine
                .animation(loadingAnimation, value: isGridDimmed)
        }
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: showsTerms)
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: showsFilters)
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: savedAt)
    }

    /// Where the header stops covering the grid: its bottom while it shows, the status bar's once it has tucked
    /// away. Hiding only offsets the header, so this reads its resting frame either way.
    private var coveredTopReader: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let edge = isHeaderShown ? frame.maxY : frame.minY
            Color.clear
                .onAppear { coveredTop.y = edge }
                .onChange(of: edge) { coveredTop.y = $0 }
        }
    }

    @ViewBuilder
    private var completionList: some View {
        if !completions.isEmpty {
            SearchCompletionListView(query: search.query, completions: completions, onChoose: choose, onFill: fill)
                .fixedSize(horizontal: false, vertical: true)
                // Hangs below the field instead of taking room in the header.
                .alignmentGuide(.bottom) { $0[.top] - Constants.completionsGap }
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .opacity))
        }
    }

    @ViewBuilder
    private var searchLoadingLine: some View {
        if isGridDimmed {
            LoadingLineView(label: "Searching")
                .transition(.opacity)
        }
    }

    private var grid: some View {
        Group {
            if showsSearchResults {
                PagedGridView(pages: search.results,
                              aspectRatio: \.aspectRatio,
                              imageURL: \.gridImageURL,
                              emptyState: .init(systemImage: "magnifyingglass",
                                                title: "No photos found",
                                                detail: noResultsDetail),
                              onItemAppear: loadMoreResults,
                              onRetry: retrySearch) { photo, width in
                    PhotoTileView(photo: photo, width: width)
                }
            } else {
                PagedGridView(pages: feed.pages,
                              aspectRatio: \.aspectRatio,
                              imageURL: \.gridImageURL,
                              emptyState: .init(systemImage: "photo.on.rectangle",
                                                title: "No photos yet",
                                                detail: "Pull down to check for new photos."),
                              onItemAppear: loadMoreCurated,
                              onRetry: retryCurated) { photo, width in
                    PhotoTileView(photo: photo, width: width)
                }
            }
        }
        // Old photos stay dimmed until a new search answers, rather than flashing a skeleton.
        .opacity(isGridDimmed ? Constants.replacingOpacity : 1)
        .allowsHitTesting(!isGridDimmed)
        .animation(loadingAnimation, value: isGridDimmed)
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: showsSearchResults)
    }

    private var showsTerms: Bool { isSearchFocused && search.query.isEmpty }

    /// Nothing while the field is closed, so the completions never cover a finished search.
    private var completions: [String] {
        guard isSearchFocused else { return [] }
        return completer.completions(for: search.query, recentSearches: search.recentSearches)
    }

    /// Loading shows after `Motion.loadingDelay` and clears at once, so a quick answer never flashes it.
    private var loadingAnimation: Animation {
        let animation = Motion.respecting(reduceMotion: reduceMotion, Motion.quick)
        return isGridDimmed ? animation.delay(Motion.loadingDelay) : animation
    }

    /// While there is a search to narrow. Not tied to focus, because opening a filter's menu ends editing.
    private var showsFilters: Bool { !search.query.isEmpty || search.isShowingResults }

    private var noResultsDetail: String {
        let nothing = "Nothing matches \u{201C}\(search.submittedQuery)\u{201D}"
        return search.submittedFilters.isEmpty ? "\(nothing). Try a broader word."
                                               : "\(nothing) with these filters. Try fewer filters."
    }

    /// Stays while the user types, and always under VoiceOver, where a hidden search would be hard to find.
    private var isHeaderShown: Bool { headerChrome.isShown || isSearchFocused || voiceOverEnabled }

    private var savedAt: Date? { search.isShowingResults ? search.savedAt : feed.savedAt }

    private var isWaitingForFirstResults: Bool {
        search.isShowingResults && search.results.isEmpty && search.results.phase == .loading
    }

    private var showsSearchResults: Bool { search.isShowingResults && !isWaitingForFirstResults }

    private var isGridDimmed: Bool { isWaitingForFirstResults || search.isReplacingResults }

    private func submit() {
        Task { await search.submitSearch() }
    }

    private func applyFilters(_ filters: SearchFilters) {
        Task { await search.applyFilters(filters) }
    }

    private func choose(_ term: String) {
        isSearchFocused = false
        Task { await search.search(for: term) }
    }

    private func fill(_ completion: String) {
        search.query = completion
    }

    private func rebuildCompleter() {
        completer = SearchCompleter(photos: feed.pages.items + search.results.items)
    }

    private func remove(_ term: String) {
        Task { await search.removeRecentSearch(term) }
    }

    private func refresh() async {
        if search.isShowingResults {
            await search.refresh()
        } else {
            await feed.refresh()
        }
    }

    private func loadMoreCurated(after photo: Photo) {
        Task { await feed.loadMoreIfNeeded(after: photo) }
    }

    private func loadMoreResults(after photo: Photo) {
        Task { await search.loadMoreIfNeeded(after: photo) }
    }

    private func retryCurated() {
        Task { await feed.retry() }
    }

    private func retrySearch() {
        Task { await search.retry() }
    }
}
