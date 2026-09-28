import SwiftUI

/// Filters for popular videos under the header: quality and length.
struct VideoFilterBarView: View {
    let filters: VideoFilters
    let onChange: (VideoFilters) -> Void

    var body: some View {
        FilterRowView(filters: filters, hasChoice: !filters.isEmpty, onClear: clearFilters) {
            FilterMenuView(title: "Quality", anyTitle: "Any quality",
                           options: VideoFilters.Quality.allCases, selection: filters.quality,
                           optionTitle: \.menuTitle, chipTitle: \.title) { value in
                change { $0.quality = value }
            }
            FilterMenuView(title: "Length", anyTitle: "Any length",
                           options: VideoFilters.Length.allCases, selection: filters.length,
                           optionTitle: \.menuTitle, chipTitle: \.title) { value in
                change { $0.length = value }
            }
        }
        .accessibilityIdentifier("videoFilters")
    }

    private func clearFilters() {
        onChange(VideoFilters())
    }

    private func change(_ edit: (inout VideoFilters) -> Void) {
        var changed = filters
        edit(&changed)
        onChange(changed)
    }
}

private extension VideoFilters.Quality {
    var title: String {
        switch self {
        case .highDefinition: "HD"
        case .fullHighDefinition: "Full HD"
        case .ultraHighDefinition: "4K"
        }
    }

    var menuTitle: String { "\(title) and up" }
}

private extension VideoFilters.Length {
    var title: String {
        switch self {
        case .short: "Short"
        case .medium: "Medium"
        case .long: "Long"
        }
    }

    var menuTitle: String {
        switch (seconds.min, seconds.max) {
        case (nil, let max?): "\(title) · up to \(max) s"
        case (let min?, let max?): "\(title) · \(min) to \(max) s"
        case (let min?, nil): "\(title) · \(min) s and more"
        case (nil, nil): title
        }
    }
}
