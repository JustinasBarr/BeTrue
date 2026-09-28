import SwiftUI

/// The app's top level: the tabs, the floating tab bar and appearance toggle, and the viewer above them.
///
/// It builds no view models: each tab reads its services from the environment and owns its screens.
struct RootView: View {
    private enum Appearance: String {
        case dark
        case light
    }

    private enum Constants {
        static let chromeMargin: CGFloat = 16
        static let chromeBottomPadding: CGFloat = 8
    }

    let dependencies: AppDependencies

    @StateObject private var router = AppRouter()
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @StateObject private var scrollChrome = ScrollChromeModel()
    /// Counts taps on each tab while it is already open; a change scrolls that tab to the top.
    @State private var scrollToTopRequests: [AppRouter.Tab: Int] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            if dependencies.hasAPIKey {
                tabs
            } else {
                missingKey
            }
            if let presentation = router.presentation {
                ViewerView(presentation: presentation,
                           onClose: router.beginClosingViewer,
                           onClosed: router.dismissViewer)
                    .id(presentation.item.id)
                    .zIndex(1)
            }
            floatingChrome
                .zIndex(2)
        }
        .preferredColorScheme(isDark ? .dark : .light)
        .routedAlert(router)
        .environmentObject(router)
        .dependencies(dependencies)
    }

    private var isDark: Bool { appearance != Appearance.light.rawValue }

    /// The bars leave while the viewer is open and return as its image flies back to the grid.
    private var isViewerOpen: Bool { router.presentation.map { !$0.isClosing } ?? false }

    private var tabs: some View {
        // Paged, so a sideways swipe moves between Photos and Videos, as the floating bar does.
        TabView(selection: $router.selectedTab) {
            PhotosTabView(scrollToTopRequest: scrollToTopRequests[.photos, default: 0],
                          headerChrome: scrollChrome.chrome.header,
                          onScroll: { scrolled(to: $0, in: .photos) })
                .tag(AppRouter.Tab.photos)
            VideosTabView(scrollToTopRequest: scrollToTopRequests[.videos, default: 0],
                          onScroll: { scrolled(to: $0, in: .videos) })
                .tag(AppRouter.Tab.videos)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // A swipe changes the tab without `select`, and the new page starts from its own offset.
        .onChange(of: router.selectedTab) { _ in scrollChrome.reset() }
        .ignoresSafeArea(edges: .bottom)
        .hidesBottomScrollEdgeEffect()
    }

    private var floatingChrome: some View {
        ZStack {
            if dependencies.hasAPIKey {
                FloatingTabBarView(items: [
                    .init(value: AppRouter.Tab.photos, title: String(localized: "Photos"),
                          systemImage: "photo.on.rectangle", identifier: "tab.photos"),
                    .init(value: AppRouter.Tab.videos, title: String(localized: "Videos"),
                          systemImage: "play.rectangle", identifier: "tab.videos")
                ], selection: router.selectedTab, onSelect: select)
                .scrollChromeBar(scrollChrome.chrome.bar)
                .floatingHidden(isViewerOpen)
            }
            AppearanceToggleView(isDark: isDark, isHidden: isViewerOpen, action: toggleAppearance)
                .scrollChromeBar(scrollChrome.chrome.bar)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, Constants.chromeMargin)
        }
        .padding(.bottom, Constants.chromeBottomPadding)
    }

    private var missingKey: some View {
        StateView(systemImage: "key",
                  title: String(localized: "Add your API key"),
                  detail: String(localized: """
                    BeTrue. needs a Pexels API key to load photos. Copy Config/Secrets.example.plist \
                    to BeTrue/App/Secrets.plist, paste your key as PexelsAPIKey, then build and run again.
                    """),
                  identifier: "missingAPIKey")
            .background(Palette.ground)
    }

    /// Re-selecting the open tab scrolls it back to the top, like the system apps.
    private func select(_ tab: AppRouter.Tab) {
        if tab == router.selectedTab {
            scrollToTopRequests[tab, default: 0] += 1
        }
        // One transaction: a chrome change outside the animation would make the page switch snap.
        withAnimation(Motion.respecting(reduceMotion: reduceMotion, Motion.hero)) {
            router.select(tab)
            scrollChrome.reset()
        }
    }

    /// Both pages stay loaded, so only the page on screen drives the chrome.
    private func scrolled(to offset: CGFloat, in tab: AppRouter.Tab) {
        guard tab == router.selectedTab else { return }
        scrollChrome.scrolled(to: offset)
    }

    private func toggleAppearance() {
        appearance = (isDark ? Appearance.light : Appearance.dark).rawValue
    }
}
