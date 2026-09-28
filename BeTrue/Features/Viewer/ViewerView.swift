import AVFoundation
import SwiftUI

/// The full-screen viewer, shown by `RootView` above the tabs.
///
/// Opening zooms the image out of its grid picture's frame to the centre of the screen while the ground and bars
/// fade in; closing flies it back into that frame, as in Photos. The frame comes from the window, not from a
/// matched geometry effect, which misplaces views that live in another tab's hosting layer. A video flies as its
/// still, hands over to its own first frame as soon as that is in, and only starts playing once it has landed.
struct ViewerView: View {
    let presentation: ViewerPresentation
    /// Called as the image starts flying back to the grid.
    let onClose: () -> Void
    /// Called once the image has landed in the grid, to remove the viewer.
    let onClosed: () -> Void
    @Environment(\.imageLoader) private var imageLoader

    var body: some View {
        ViewerContentView(item: presentation.item,
                          source: presentation.source,
                          coveredTop: presentation.coveredTop,
                          imageLoader: imageLoader,
                          onClose: onClose,
                          onClosed: onClosed)
    }
}

private struct ViewerContentView: View {
    private enum Constants {
        /// Long enough that a tap on the player's own controls never starts a dismiss.
        static let videoDragMinimumDistance: CGFloat = 16
    }

    let source: ViewerSourceFrame
    let coveredTop: ViewerCoveredTop?
    let onClose: () -> Void
    let onClosed: () -> Void
    @StateObject private var viewModel: ViewerViewModel
    @State private var isChromeVisible = true
    @State private var isZoomed = false
    @State private var dragTranslation = CGSize.zero
    @State private var isDragging = false
    @State private var isPresented = false
    /// True once the opening flight has come to rest. The player and the full image wait for it, because
    /// SwiftUI drives the flight on the main thread and any work there during it costs frames.
    @State private var hasLanded = false
    /// True once the video's first frame is on screen, so the still hands over to it without a black flash.
    @State private var isVideoFrameReady = false
    /// True once the system player has drawn over that frame, so its controls never appear over black.
    @State private var isPlayerReady = false
    @State private var isClosing = false
    /// The screen's size as the viewer opened. Turned sideways since, the grid may not have laid out the new size yet.
    @State private var openedSize: CGSize?
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.displayScale) private var displayScale

    private var item: ViewerItem { viewModel.item }

    private var presenceAnimation: Animation {
        Motion.respecting(reduceMotion: reduceMotion, Motion.hero)
    }

    /// How long the open or close animation takes to come to rest.
    private var settleDuration: TimeInterval {
        reduceMotion ? Motion.fadeDuration : Motion.heroSettleDuration
    }

    private var showsChrome: Bool {
        isPresented && !isDragging && (isChromeVisible || voiceOverEnabled || viewModel.isVideo)
    }

    private var showsVideo: Bool {
        isPresented && isVideoFrameReady
    }

    /// Open and still: false during both flights, so the full image never swaps in while the image moves.
    private var isAtRest: Bool {
        hasLanded && !isClosing
    }

    /// Measured in the window: the video moves with the finger, so its own space would move the translation
    /// under the finger, feed it back into the offset and never settle.
    private var videoDismissDrag: some Gesture {
        DragGesture(minimumDistance: Constants.videoDragMinimumDistance, coordinateSpace: .global)
            .onChanged { updateDrag($0.translation) }
            .onEnded { endDrag($0.translation, projectedTranslation: $0.predictedEndTranslation) }
    }

    init(item: ViewerItem,
         source: ViewerSourceFrame,
         coveredTop: ViewerCoveredTop?,
         imageLoader: any ImageLoading,
         onClose: @escaping () -> Void,
         onClosed: @escaping () -> Void) {
        self.source = source
        self.coveredTop = coveredTop
        self.onClose = onClose
        self.onClosed = onClosed
        _viewModel = StateObject(wrappedValue: ViewerViewModel(item: item, imageLoader: imageLoader))
    }

    var body: some View {
        ZStack {
            Palette.ground
                .opacity(isPresented ? 1 - DismissDragPolicy.progress(for: dragTranslation) : 0)
                .ignoresSafeArea()
            GeometryReader { proxy in
                media(in: proxy)
                    .onAppear { openedSize = proxy.size }
                    .task(id: isAtRest) {
                        // A video's own frame already covers the still, so it needs no sharper copy.
                        guard isAtRest, !isVideoFrameReady else { return }
                        let longestSide = max(proxy.size.width, proxy.size.height)
                        await viewModel.loadFullImage(maxPixelSize: longestSide * displayScale)
                    }
            }
            .ignoresSafeArea()
            ViewerChromeView(item: item, onClose: dismiss)
                .opacity(showsChrome ? 1 : 0)
                .allowsHitTesting(showsChrome)
                .accessibilityHidden(!showsChrome)
                .animation(Motion.quick, value: showsChrome)
        }
        .statusBarHidden(!showsChrome)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("viewer")
        .accessibilityAction(.escape, dismiss)
        .onAppear {
            withAnimation(presenceAnimation) { isPresented = true }
        }
        .task { await viewModel.loadPreviewIfNeeded() }
        .task { await land() }
        // Tied to the view, so a viewer replaced mid-close never removes the one that replaced it.
        .task(id: isClosing) {
            guard isClosing, (try? await Task.sleep(for: .seconds(settleDuration))) != nil else { return }
            onClosed()
        }
        .onDisappear { viewModel.pausePlayback() }
        // Only once landed, so the alert never interrupts the flight. The still stays up behind it.
        .onChange(of: hasLanded && viewModel.didPlaybackFail) { didFail in
            if didFail { router.show(.videoFailedToLoad) }
        }
    }

    /// The media is laid out once at its on-screen size; the flight and the drag only scale and move it, so neither
    /// the image nor the player is measured again on any frame.
    private func media(in proxy: GeometryProxy) -> some View {
        let container = proxy.size
        let fitted = fittedSize(in: container)
        let origin = proxy.frame(in: .global).origin
        // Read on every pass rather than kept from opening: a turn sideways and back re-lays the grid out.
        let tile = source.frame.offsetBy(dx: -origin.x, dy: -origin.y)
        let hasResized = openedSize.map { $0 != container } ?? false
        let isSourceOnScreen = !tile.isEmpty && tile.intersects(CGRect(origin: .zero, size: container))
        // Closed, the image sits exactly on its grid picture; Reduce Motion, a resize or a picture now off screen
        // fades it in place instead.
        let fadesInPlace = reduceMotion || hasResized || !isSourceOnScreen
        let coveredY = coveredTop?.y ?? 0
        let isOnSource = !isPresented && !fadesInPlace && fitted != .zero
        let dragScale = DismissDragPolicy.scale(for: dragTranslation, reduceMotion: reduceMotion)
        let scale = isOnSource
            ? CGSize(width: tile.width / fitted.width, height: tile.height / fitted.height)
            : CGSize(width: dragScale, height: dragScale)
        let offset = isOnSource
            ? CGSize(width: tile.midX - container.width / 2, height: tile.midY - container.height / 2)
            : DismissDragPolicy.offset(for: dragTranslation)
        // Scaled down with the image, so the corners match the grid picture's once on screen.
        let cornerRadius = isOnSource ? Radius.tile / max(scale.width, .leastNonzeroMagnitude) : 0
        return ZStack {
            mediaContent
                .frame(width: fitted.width, height: fitted.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .opacity(isZoomed ? 0 : 1)
                .scaleEffect(x: scale.width, y: scale.height)
                .offset(offset)
                .opacity(fadesInPlace && !isPresented ? 0 : 1)
                .frame(width: container.width, height: container.height)
                .beneathHeader(isPresented: isPresented, height: coveredY - origin.y, when: coveredY > 0)
            if !viewModel.isVideo {
                ZoomableImageView(image: viewModel.image,
                                  aspectRatio: item.aspectRatio,
                                  isHidden: isClosing,
                                  onSingleTap: toggleChrome,
                                  onZoomChange: { isZoomed = $0 },
                                  onDismissDragChange: updateDrag,
                                  onDismissDragEnd: endDrag)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: container.width, height: container.height)
        // A video can be dragged away from anywhere, as a photo can.
        .contentShape(Rectangle())
        .simultaneousGesture(videoDismissDrag, including: viewModel.isVideo ? .all : .subviews)
    }

    private var mediaContent: some View {
        ZStack {
            Color(hex: item.placeholderColor) ?? Palette.fill
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(.isImage)
        .overlay {
            if let player = viewModel.player {
                video(player)
            }
        }
    }

    /// The video's picture flies with the still and fades in over it as soon as its first frame is in, ideally
    /// mid-flight, where the motion hides that the provider's still is another moment of the video. The system player
    /// only joins once the flight has landed, because making it costs frames, and draws the same frame on top.
    private func video(_ player: AVPlayer) -> some View {
        ZStack {
            ViewerVideoSurfaceView(player: player) { isVideoFrameReady = true }
            if hasLanded {
                ViewerVideoPlayerView(player: player) { isPlayerReady = true }
                    .opacity(isPlayerReady ? 1 : 0)
                    .animation(Motion.imageFade, value: isPlayerReady)
            }
        }
        .opacity(showsVideo ? 1 : 0)
        .animation(Motion.imageFade, value: showsVideo)
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0 else { return .zero }
        let ratio = max(CGFloat(item.aspectRatio), .leastNonzeroMagnitude)
        if container.width / container.height > ratio {
            return CGSize(width: container.height * ratio, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / ratio)
    }

    private func toggleChrome() {
        isChromeVisible.toggle()
    }

    /// iOS 16 has no animation completion, so wait for the flight to settle before starting heavy work.
    private func land() async {
        guard (try? await Task.sleep(for: .seconds(settleDuration))) != nil, isPresented else { return }
        hasLanded = true
        viewModel.startPlayback()
    }

    private func updateDrag(_ translation: CGSize) {
        guard isPresented else { return }
        isDragging = true
        dragTranslation = translation
    }

    private func endDrag(_ translation: CGSize, projectedTranslation: CGSize) {
        guard isPresented else { return }
        if DismissDragPolicy.shouldDismiss(translation: translation, projectedTranslation: projectedTranslation) {
            dismiss()
            return
        }
        withAnimation(Motion.respecting(reduceMotion: reduceMotion, Motion.hero)) {
            dragTranslation = .zero
            isDragging = false
        }
    }

    private func dismiss() {
        guard isPresented else { return }
        viewModel.pausePlayback()
        onClose()
        isClosing = true
        // Only the SwiftUI image can fly back to the tile, so it takes over from a zoomed UIKit image at once, in
        // the frame that one hides. Faded in, the flight would start see-through.
        isZoomed = false
        withAnimation(presenceAnimation) {
            isPresented = false
        }
    }
}

private extension View {
    /// Hides the part of the image over the screen's header while the viewer is closed. It fades with the ground,
    /// so the header shows through as the image leaves it, and the image lands wholly beneath it. Only where a header
    /// covers the grid, so no other image, and no video, is ever drawn through a mask.
    @ViewBuilder
    func beneathHeader(isPresented: Bool, height: CGFloat, when isCovered: Bool) -> some View {
        if isCovered {
            mask {
                VStack(spacing: 0) {
                    Color.black
                        .opacity(isPresented ? 1 : 0)
                        .frame(height: max(height, 0))
                    Color.black
                }
            }
        } else {
            self
        }
    }
}

struct ViewerView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewHostView()
    }

    private struct PreviewHostView: View {
        var body: some View {
            ViewerView(presentation: ViewerPresentation(item: .sample, source: ViewerSourceFrame(), coveredTop: nil),
                       onClose: {},
                       onClosed: {})
                .environmentObject(AppRouter())
        }
    }
}

private extension ViewerItem {
    static let sample = ViewerItem(
        id: "photo-2014422",
        aspectRatio: 2 / 3,
        placeholderColor: "#6E6A5E",
        previewURL: URL(string: "https://images.pexels.com/photos/2014422/pexels-photo-2014422.jpeg?w=640")!,
        fullImageURL: URL(string: "https://images.pexels.com/photos/2014422/pexels-photo-2014422.jpeg?w=2000")!,
        title: "Sample photo with a caption long enough to need a second line in the viewer",
        creditName: "Sample photographer",
        creditURL: URL(string: "https://www.pexels.com/photo/2014422/"),
        pageURL: URL(string: "https://www.pexels.com/photo/2014422/")!,
        videoURL: nil)
}
