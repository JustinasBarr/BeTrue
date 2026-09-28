import SwiftUI

/// The viewer's bars: close and share above the picture, the title and credit below it.
struct ViewerChromeView: View {
    private enum Constants {
        static let barHeight: CGFloat = 44
        static let glyphSize: CGFloat = 44
        static let barPadding: CGFloat = 4
        static let captionHorizontalPadding: CGFloat = 16
        static let captionVerticalPadding: CGFloat = 12
        static let captionSpacing: CGFloat = 4
        static let titleLineLimit = 2
        /// Tall enough to read a long caption, short enough to leave most of the picture in view.
        static let expandedCaptionMaxHeight: CGFloat = 280
    }

    let item: ViewerItem
    let onClose: () -> Void
    @State private var isCaptionExpanded = false
    /// True when the title needs more than its collapsed lines, the only case in which the caption opens.
    @State private var isTitleTruncated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var captionAnimation: Animation {
        Motion.respecting(reduceMotion: reduceMotion, Motion.quick)
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: Constants.glyphSize, height: Constants.glyphSize)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("viewerClose")
            Spacer()
            ShareLink(item: item.pageURL) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: Constants.glyphSize, height: Constants.glyphSize)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share")
            .accessibilityIdentifier("viewerShare")
        }
        .buttonStyle(GlyphButtonStyle())
        .font(Typography.headline)
        .foregroundColor(Palette.ink)
        .padding(.horizontal, Constants.barPadding)
        .frame(height: Constants.barHeight)
        .background(Palette.ground.ignoresSafeArea(edges: .top))
    }

    /// A tap on a cut-off caption grows it upwards to show the whole title; a tap on the picture folds it back.
    private var caption: some View {
        ViewThatFits(in: .vertical) {
            captionContent
            // Only a caption taller than the cap scrolls.
            ScrollView { captionContent }
        }
        .frame(maxHeight: isCaptionExpanded ? Constants.expandedCaptionMaxHeight : nil)
        .clipped()
        .background(Palette.ground.ignoresSafeArea(edges: .bottom))
        .contentShape(Rectangle())
        .onTapGesture {
            guard isTitleTruncated || isCaptionExpanded else { return }
            withAnimation(captionAnimation) { isCaptionExpanded.toggle() }
        }
    }

    private var captionContent: some View {
        VStack(alignment: .leading, spacing: Constants.captionSpacing) {
            title
                .foregroundColor(Palette.ink)
                .lineLimit(isCaptionExpanded ? nil : Constants.titleLineLimit)
                .background { truncationProbe }
            credit
                .font(Typography.caption)
                .foregroundColor(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.captionHorizontalPadding)
        .padding(.vertical, Constants.captionVerticalPadding)
    }

    private var title: Text {
        Text(item.title).font(Typography.headline)
    }

    /// The whole title measured against its collapsed lines: when it does not fit, the caption can open.
    private var truncationProbe: some View {
        title
            .lineLimit(Constants.titleLineLimit)
            .hidden()
            .overlay {
                ViewThatFits(in: .vertical) {
                    title.hidden().onAppear { isTitleTruncated = false }
                    Color.clear.onAppear { isTitleTruncated = true }
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var credit: some View {
        let text = Text("\(item.videoURL == nil ? "Photo" : "Video") by \(item.creditName)")
        if let creditURL = item.creditURL {
            Link(destination: creditURL) { text.underline() }
                .accessibilityHint(item.videoURL == nil
                                   ? "Opens the photographer's page"
                                   : "Opens the videographer's page")
        } else {
            text
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            caption
        }
        .background {
            if isCaptionExpanded {
                // Catches the tap on the picture, so it folds the caption instead of zooming or hiding the bars.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(captionAnimation) { isCaptionExpanded = false } }
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Bar glyphs dim while pressed, like native bar buttons, instead of scaling.
private struct GlyphButtonStyle: ButtonStyle {
    private enum Constants {
        static let pressedOpacity = 0.4
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Constants.pressedOpacity : 1)
    }
}
