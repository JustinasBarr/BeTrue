import Combine
import SwiftUI

/// Popular videos in the same masonry grid as photos. A tap plays the video in the shared viewer.
struct VideoFeedView: View {
    private enum Constants {
        static let coordinateSpace = "videosScroll"
        static let topID = "videosTop"
        static let headerTopPadding: CGFloat = 8
        static let headerBottomPadding: CGFloat = 12
        static let headerSpacing: CGFloat = 12
        static let replacingOpacity = 0.4
    }

    let scrollToTopRequest: Int
    let onScroll: (CGFloat) -> Void

    @StateObject private var viewModel: VideoFeedViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(repository: any VideoRepository,
         onlineUpdates: AnyPublisher<Bool, Never>,
         scrollToTopRequest: Int,
         onScroll: @escaping (CGFloat) -> Void) {
        _viewModel = StateObject(wrappedValue: VideoFeedViewModel(repository: repository, onlineUpdates: onlineUpdates))
        self.scrollToTopRequest = scrollToTopRequest
        self.onScroll = onScroll
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ScrollOffsetMarkerView(coordinateSpace: Constants.coordinateSpace)
                        .id(Constants.topID)
                    header
                    content
                }
            }
            .onScrollOffsetChange(coordinateSpace: Constants.coordinateSpace, perform: onScroll)
            .refreshable { await viewModel.refresh() }
            .onChange(of: scrollToTopRequest) { _ in
                withAnimation(Motion.respecting(reduceMotion: reduceMotion, Motion.hero)) {
                    proxy.scrollTo(Constants.topID, anchor: .top)
                }
            }
        }
        .background(Palette.ground)
        .task { await viewModel.loadFirstPage() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Constants.headerSpacing) {
            ScreenHeaderView(title: "Videos")
            VideoFilterBarView(filters: viewModel.filters, onChange: applyFilters)
            if let savedAt = viewModel.savedAt {
                SavedCopyBannerView(savedAt: savedAt)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, Constants.headerTopPadding)
        .padding(.bottom, Constants.headerBottomPadding)
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: viewModel.savedAt)
    }

    private var content: some View {
        PagedGridView(pages: viewModel.pages,
                      aspectRatio: \.aspectRatio,
                      imageURL: \.gridImageURL,
                      emptyState: emptyState,
                      onItemAppear: loadMore,
                      onRetry: retry) { video, width in
            VideoTileView(video: video, width: width)
        }
        // Old videos stay dimmed until the new filters answer, rather than flashing a skeleton.
        .opacity(viewModel.isReplacingVideos ? Constants.replacingOpacity : 1)
        .allowsHitTesting(!viewModel.isReplacingVideos)
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: viewModel.isReplacingVideos)
    }

    private var emptyState: PagedGridView<Video, VideoTileView>.EmptyState {
        viewModel.filters.isEmpty
            ? .init(systemImage: "play.rectangle", title: "No videos yet",
                    detail: "Pull down to check for new videos.")
            : .init(systemImage: "play.rectangle", title: "No videos found",
                    detail: "No popular videos match these filters. Try fewer filters.")
    }

    private func applyFilters(_ filters: VideoFilters) {
        Task { await viewModel.applyFilters(filters) }
    }

    private func loadMore(after video: Video) {
        Task { await viewModel.loadMoreIfNeeded(after: video) }
    }

    private func retry() {
        Task { await viewModel.retry() }
    }
}
