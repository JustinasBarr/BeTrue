import AVKit
import Combine
import SwiftUI

/// The system player and its controls. It reports when its first frame is on screen, so the viewer can hand over
/// from the picture beneath it without a black flash.
struct ViewerVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let onReadyForDisplay: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        // Fills like the picture beneath it, so the two line up exactly.
        controller.videoGravity = .resizeAspectFill
        // Clear rather than black, so the picture behind it shows wherever the video does not.
        controller.view.backgroundColor = .clear
        context.coordinator.readyForDisplay = controller.publisher(for: \.isReadyForDisplay)
            .firstReady(onReadyForDisplay)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }

    func makeCoordinator() -> ReadyForDisplayObserver {
        ReadyForDisplayObserver()
    }
}

/// The video's picture alone, without controls. It is light enough to fly with the still, so the video's first frame
/// can take over during the flight, where the motion hides that the provider's still is another moment of the video.
struct ViewerVideoSurfaceView: UIViewRepresentable {
    let player: AVPlayer
    let onReadyForDisplay: () -> Void

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer?.player = player
        // Fills like the still it covers.
        view.playerLayer?.videoGravity = .resizeAspectFill
        context.coordinator.readyForDisplay = view.playerLayer?.publisher(for: \.isReadyForDisplay)
            .firstReady(onReadyForDisplay)
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        if view.playerLayer?.player !== player {
            view.playerLayer?.player = player
        }
    }

    func makeCoordinator() -> ReadyForDisplayObserver {
        ReadyForDisplayObserver()
    }

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }
}

final class ReadyForDisplayObserver {
    var readyForDisplay: AnyCancellable?
}

private extension Publisher where Output == Bool, Failure == Never {
    /// Calls back once, on the main thread, the first time the video has a frame on screen.
    func firstReady(_ onReady: @escaping () -> Void) -> AnyCancellable {
        receive(on: DispatchQueue.main)
            .first { $0 }
            .sink { _ in onReady() }
    }
}
