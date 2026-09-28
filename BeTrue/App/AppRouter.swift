import Combine
import SwiftUI

/// App-wide navigation: the selected tab, the item shown full screen, and alerts.
///
/// No screen pushes another yet, so the tabs hold no `NavigationStack`: one inside the paged tabs sits outside the
/// view controller tree, and every menu opened from it warns. A pushed screen would bring the stack back as a
/// value route per feature.
final class AppRouter: ObservableObject {
    enum Tab: Hashable, CaseIterable {
        case photos
        case videos
    }

    @Published var selectedTab = Tab.photos
    @Published private(set) var presentation: ViewerPresentation?
    @Published private(set) var alert: AppAlert?

    /// The item the viewer shows, while it is open or closing.
    var presentedItem: ViewerItem? { presentation?.item }

    func select(_ tab: Tab) {
        selectedTab = tab
    }

    /// Opens the viewer on `item`, zooming out of its grid picture at `source` and back into it on close. The image
    /// passes beneath `coveredTop`, the bottom of the screen's pinned header.
    func present(_ item: ViewerItem, from source: ViewerSourceFrame, coveredTop: ViewerCoveredTop?) {
        presentation = ViewerPresentation(item: item, source: source, coveredTop: coveredTop)
    }

    /// The viewer's image has started flying back to the grid, so the bars can return alongside it.
    func beginClosingViewer() {
        presentation?.isClosing = true
    }

    func dismissViewer() {
        presentation = nil
    }

    func show(_ alert: AppAlert) {
        self.alert = alert
    }

    func dismissAlert() {
        alert = nil
    }
}

/// A message that needs the user's attention before they continue.
struct AppAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

extension View {
    /// Shows the router's alert over this view.
    func routedAlert(_ router: AppRouter) -> some View {
        alert(router.alert?.title ?? "",
              isPresented: Binding { router.alert != nil } set: { if !$0 { router.dismissAlert() } },
              presenting: router.alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}
