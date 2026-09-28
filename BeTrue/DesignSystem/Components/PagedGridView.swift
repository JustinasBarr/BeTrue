import SwiftUI

/// A paged masonry grid with its loading, failure and empty states and the load-more footer.
struct PagedGridView<Item: Identifiable & Sendable, Cell: View>: View where Item.ID: Sendable {
    private enum Constants {
        static var stateMinHeight: CGFloat { 420 }
    }

    let pages: Paginator<Item>
    let aspectRatio: KeyPath<Item, Double>
    /// The image each tile shows, so the grid can load the ones below the screen ahead of time.
    let imageURL: KeyPath<Item, URL>
    let emptyState: EmptyState
    let onItemAppear: (Item) -> Void
    let onRetry: () -> Void
    let cell: (Item, CGFloat) -> Cell

    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.displayScale) private var displayScale
    @StateObject private var prefetcher = ImagePrefetcher()
    @StateObject private var offlineKeeper = OfflineImageKeeper()

    struct EmptyState {
        let systemImage: String
        let title: String
        let detail: String
    }

    init(pages: Paginator<Item>,
         aspectRatio: KeyPath<Item, Double>,
         imageURL: KeyPath<Item, URL>,
         emptyState: EmptyState,
         onItemAppear: @escaping (Item) -> Void,
         onRetry: @escaping () -> Void,
         @ViewBuilder cell: @escaping (_ item: Item, _ columnWidth: CGFloat) -> Cell) {
        self.pages = pages
        self.aspectRatio = aspectRatio
        self.imageURL = imageURL
        self.emptyState = emptyState
        self.onItemAppear = onItemAppear
        self.onRetry = onRetry
        self.cell = cell
    }

    var body: some View {
        VStack(spacing: 0) {
            if !pages.isEmpty {
                MasonryGridView(items: pages.items, aspectRatio: aspectRatio) { item, columnWidth in
                    cell(item, columnWidth)
                        .onAppear { itemAppeared(item, columnWidth: columnWidth) }
                }
                LoadMoreFooterView(status: footerStatus, onRetry: onRetry)
            } else {
                switch pages.phase {
                case .idle, .loading:
                    SkeletonGridView()
                case .failed(let error):
                    StateView(systemImage: error.systemImage, title: error.title, detail: error.detail,
                              action: error.canRetry ? StateView.Action(title: "Try again", perform: onRetry) : nil)
                        .frame(minHeight: Constants.stateMinHeight)
                case .loaded, .finished:
                    StateView(systemImage: emptyState.systemImage, title: emptyState.title,
                              detail: emptyState.detail)
                        .frame(minHeight: Constants.stateMinHeight)
                }
            }
        }
        // A replaced list puts other items at the same positions.
        .onChange(of: pages.items.first?.id) { _ in prefetcher.startOver() }
    }

    private func itemAppeared(_ item: Item, columnWidth: CGFloat) {
        onItemAppear(item)
        guard let position = pages.position(of: item.id) else { return }
        let items = pages.items
        prefetcher.itemAppeared(at: position, count: items.count, loader: imageLoader) { index in
            let next = items[index]
            let ratio = next[keyPath: aspectRatio]
            guard ratio > 0 else { return nil }
            // The same size the tile asks for, so the prefetched image is the one the tile reads.
            return ImageRequest(url: next[keyPath: imageURL],
                                pointSize: CGSize(width: columnWidth, height: columnWidth / ratio),
                                displayScale: displayScale)
        }
        offlineKeeper.scrolled(through: items, imageURL: imageURL, loader: imageLoader)
    }

    private var footerStatus: LoadMoreFooterView.Status {
        switch pages.phase {
        case .idle, .loaded: return .idle
        case .loading: return .loading
        case .failed(let error): return .failed(message: error.shortMessage)
        case .finished: return .finished
        }
    }
}
