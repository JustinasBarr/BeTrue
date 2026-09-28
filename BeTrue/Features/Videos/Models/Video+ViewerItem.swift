import Foundation

extension ViewerItem {
    init(video: Video) {
        self.init(id: video.viewerID,
                  aspectRatio: video.aspectRatio,
                  placeholderColor: nil,
                  previewURL: video.gridImageURL,
                  fullImageURL: video.thumbnailURL(pixelWidth: Video.fullPixelWidth),
                  title: video.caption,
                  creditName: video.user.name,
                  creditURL: video.user.url,
                  pageURL: video.pageURL,
                  videoURL: video.playbackURL)
    }
}

extension Video {
    /// Videos share the grid with photos, so their tiles request the same width.
    nonisolated static let gridPixelWidth = Photo.gridPixelWidth
    /// The still frame only shows until playback starts, so it needs less than a zoomable photo.
    static let fullPixelWidth = 1600

    /// What the grid tile shows. The grid's prefetcher asks for the same URL, so both share one cache entry.
    nonisolated var gridImageURL: URL { thumbnailURL(pixelWidth: Self.gridPixelWidth) }

    /// Shared by the grid tile and the viewer so the hero transition matches them.
    var viewerID: String { "video-\(id)" }
}
