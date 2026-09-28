import SwiftUI

/// One photo in the grid, labelled with its description. Opens in the viewer.
struct PhotoTileView: View {
    let photo: Photo
    let width: CGFloat

    var body: some View {
        let item = ViewerItem(photo: photo)
        let size = CGSize(width: width, height: width / photo.aspectRatio)
        ViewerTileView(item: item, size: size) {
            RemoteImageView(url: item.previewURL,
                            pointSize: size,
                            placeholder: Color(hex: photo.averageColor) ?? Palette.fill)
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .bottomLeading) {
                    if !photo.caption.isEmpty {
                        TileLabelView { Text(photo.caption) }
                    }
                }
        }
        .accessibilityLabel(photo.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("photoTile")
    }
}

extension Photo {
    var accessibilityDescription: String {
        photographer.isEmpty ? caption : "\(caption), photo by \(photographer)"
    }
}
