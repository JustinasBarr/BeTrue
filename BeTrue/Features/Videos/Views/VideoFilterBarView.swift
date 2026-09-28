import SwiftUI

/// Filters for popular videos under the header: quality and length.
struct VideoFilterBarView: View {
    let filters: VideoFilters
    let onChange: (VideoFilters) -> Void

    var body: some View {
        FilterRowView(filters: filters, hasChoice: !filters.isEmpty, onClear: clearFilters) {
            FilterMenuView(title: String(localized: "Quality"), anyTitle: String(localized: "Any quality"),
                           options: VideoFilters.Quality.allCases, selection: filters.quality,
                           optionTitle: \.menuTitle, chipTitle: \.title) { value in
                change { $0.quality = value }
            }
            FilterMenuView(title: String(localized: "Length"), anyTitle: String(localized: "Any length"),
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

    var menuTitle: String { String(localized: "\(title) and up") }
}

private extension VideoFilters.Length {
    var title: String {
        switch self {
        case .short: String(localized: "Short")
        case .medium: String(localized: "Medium")
        case .long: String(localized: "Long")
        }
    }

    var menuTitle: String {
        switch (seconds.min, seconds.max) {
        case (nil, let max?): String(localized: "\(title) · up to \(max) s")
        case (let min?, let max?): String(localized: "\(title) · \(min) to \(max) s")
        case (let min?, nil): String(localized: "\(title) · \(min) s and more")
        case (nil, nil): title
        }
    }
}
