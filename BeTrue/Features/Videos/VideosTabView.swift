import Combine
import SwiftUI

/// The Videos tab. Reads its services from the environment and hands them to the screen.
struct VideosTabView: View {
    /// Changes each time the open Videos tab is tapped again.
    let scrollToTopRequest: Int
    let onScroll: (CGFloat) -> Void

    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.videoRepository) private var repository

    var body: some View {
        VideoFeedView(repository: repository,
                      onlineUpdates: networkMonitor.$isOnline.eraseToAnyPublisher(),
                      scrollToTopRequest: scrollToTopRequest,
                      onScroll: onScroll)
    }
}
