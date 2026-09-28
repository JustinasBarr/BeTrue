import Foundation

extension ViewerItem {
    init(photo: Photo) {
        self.init(id: "photo-\(photo.id)",
                  aspectRatio: photo.aspectRatio,
                  placeholderColor: photo.averageColor,
                  previewURL: photo.gridImageURL,
                  fullImageURL: photo.imageURL(pixelWidth: Photo.fullPixelWidth),
                  title: photo.caption,
                  creditName: photo.photographer,
                  creditURL: photo.photographerURL,
                  pageURL: photo.pageURL,
                  videoURL: nil)
    }
}

extension Photo {
    /// Width requested for grid cells: a two-column cell on the largest phone at 3x is about 640 px.
    nonisolated static let gridPixelWidth = 640
    /// Width requested for the full-screen viewer, enough for 3x zoom on a phone.
    nonisolated static let fullPixelWidth = 2000

    /// What the grid tile shows. The grid's prefetcher asks for the same URL, so both share one cache entry.
    nonisolated var gridImageURL: URL { imageURL(pixelWidth: Self.gridPixelWidth) }
}
