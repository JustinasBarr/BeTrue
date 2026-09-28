import Combine
import SwiftUI

/// The Photos tab. Reads its services from the environment and hands them to the screen.
struct PhotosTabView: View {
    /// Changes each time the Photos tab is tapped while it is already open.
    let scrollToTopRequest: Int
    let headerChrome: ScrollChrome.Header
    let onScroll: (CGFloat) -> Void

    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.photoRepository) private var repository
    @Environment(\.localStore) private var store

    var body: some View {
        PhotoFeedView(repository: repository,
                      store: store,
                      onlineUpdates: networkMonitor.$isOnline.eraseToAnyPublisher(),
                      scrollToTopRequest: scrollToTopRequest,
                      headerChrome: headerChrome,
                      onScroll: onScroll)
            .tint(Palette.ink)
    }
}
