import SwiftUI

/// A grid picture that opens in the viewer. Photos and videos both use it, so both open and close the same way:
/// the viewer zooms out of this picture's frame and back into it, and the picture leaves its slot empty meanwhile.
struct ViewerTileView<Content: View>: View {
    let item: ViewerItem
    let size: CGSize
    let content: Content

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.viewerCoveredTop) private var coveredTop
    @State private var source = ViewerSourceFrame()

    init(item: ViewerItem, size: CGSize, @ViewBuilder content: () -> Content) {
        self.item = item
        self.size = size
        self.content = content()
    }

    var body: some View {
        Button(action: open) {
            content
                .frame(width: size.width, height: size.height)
                .clipShape(Radius.tileShape)
                .contentShape(Radius.tileShape)
                // Hidden rather than removed, so the image is still loaded when the viewer lands back here.
                .opacity(router.presentedItem?.id == item.id ? 0 : 1)
        }
        .buttonStyle(TileButtonStyle())
        .background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                Color.clear
                    .onAppear { source.frame = frame }
                    .onChange(of: frame) { source.frame = $0 }
            }
        }
    }

    private func open() {
        // A video streams while it plays, so offline the grid stays and says why instead of opening a black player.
        if item.videoURL != nil, !networkMonitor.isOnline {
            router.show(.videoNeedsConnection)
            return
        }
        router.present(item, from: source, coveredTop: coveredTop)
    }
}
