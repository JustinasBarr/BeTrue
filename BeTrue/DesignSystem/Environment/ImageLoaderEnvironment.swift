import SwiftUI
import UIKit

extension EnvironmentValues {
    /// The loader that remote images use. Set once at the root; previews get one that loads nothing.
    var imageLoader: any ImageLoading {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: any ImageLoading = NoImageLoader()
}

private struct NoImageLoader: ImageLoading {
    func cachedImage(for url: URL, maxPixelSize: CGFloat) -> UIImage? { nil }
    func cachedImage(for url: URL) -> UIImage? { nil }
    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? { nil }
    func keepOffline(_ urls: [URL]) async {}
}
