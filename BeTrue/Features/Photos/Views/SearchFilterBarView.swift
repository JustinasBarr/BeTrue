import SwiftUI
import UIKit

struct SearchFilterBarView: View {
    let filters: SearchFilters
    let onChange: (SearchFilters) -> Void

    var body: some View {
        FilterRowView(filters: filters, hasChoice: !filters.isEmpty, onClear: clearFilters) {
            FilterMenuView(title: "Orientation", anyTitle: "Any orientation",
                           options: SearchFilters.Orientation.allCases, selection: filters.orientation,
                           optionTitle: \.title, optionImage: \.symbol) { value in
                change { $0.orientation = value }
            }
            FilterMenuView(title: "Size", anyTitle: "Any size",
                           options: SearchFilters.Size.allCases, selection: filters.size,
                           optionTitle: \.menuTitle, chipTitle: \.title) { value in
                change { $0.size = value }
            }
            FilterMenuView(title: "Color", anyTitle: "Any color",
                           options: SearchFilters.ColorName.allCases, selection: filters.color,
                           optionTitle: \.title, optionImage: \.menuSwatch,
                           chipSwatch: filters.color?.swatch) { value in
                change { $0.color = value }
            }
            FilterMenuView(title: "Language", anyTitle: "Any language",
                           options: SearchFilters.Language.menuOrder(), selection: filters.language,
                           optionTitle: \.title) { value in
                change { $0.language = value }
            }
        }
        .accessibilityIdentifier("searchFilters")
    }

    private func clearFilters() {
        onChange(SearchFilters())
    }

    private func change(_ edit: (inout SearchFilters) -> Void) {
        var changed = filters
        edit(&changed)
        onChange(changed)
    }
}

private extension SearchFilters.Orientation {
    var title: String { rawValue.capitalized }

    var symbol: Image { Image(systemName: systemImage) }

    private var systemImage: String {
        switch self {
        case .landscape: "rectangle"
        case .portrait: "rectangle.portrait"
        case .square: "square"
        }
    }
}

private extension SearchFilters.Size {
    var title: String { rawValue.capitalized }

    /// The smallest photo each size allows, as Pexels defines it.
    var menuTitle: String {
        switch self {
        case .large: "Large · 24 MP and up"
        case .medium: "Medium · 12 MP and up"
        case .small: "Small · 4 MP and up"
        }
    }
}

/// The one place the app's controls show colour: the swatches describe the photos.
private extension SearchFilters.ColorName {
    var title: String { rawValue.capitalized }
    var swatch: Color { Color(hex: swatchHex) ?? Palette.ink }
    var menuSwatch: Image { Image(uiImage: MenuSwatch.image(for: UIColor(swatch))) }

    private var swatchHex: String {
        switch self {
        case .red: "#E53935"
        case .orange: "#FB8C00"
        case .yellow: "#FDD835"
        case .green: "#43A047"
        case .turquoise: "#1ABC9C"
        case .blue: "#1E88E5"
        case .violet: "#8E24AA"
        case .pink: "#EC407A"
        case .brown: "#795548"
        case .black: "#000000"
        case .gray: "#9E9E9E"
        case .white: "#FFFFFF"
        }
    }
}

private extension SearchFilters.Language {
    /// The language in its own words, so its speakers find it whatever the phone's language.
    var title: String {
        let own = Locale(identifier: rawValue)
        let isShared = Self.allCases.filter { $0.languageCode == languageCode }.count > 1
        let name = isShared ? own.localizedString(forIdentifier: rawValue)
                            : own.localizedString(forLanguageCode: languageCode)
        return (name ?? rawValue).capitalized(with: own)
    }

    /// The phone's language first, when Pexels supports it, then the rest by name.
    static func menuOrder(for locale: Locale = .current) -> [Self] {
        let preferred = matching(locale)
        let rest = allCases.filter { $0 != preferred }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return (preferred.map { [$0] } ?? []) + rest
    }
}

/// Menus redraw tinted symbols in one colour, so each swatch is a small round image drawn in its own colour.
private enum MenuSwatch {
    private enum Constants {
        static let side: CGFloat = 16
        static let outlineWidth: CGFloat = 1
        /// Mid grey gives white and black swatches an edge on both menu themes.
        static let outline = UIColor(white: 0.5, alpha: 1)
    }

    static func image(for color: UIColor) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: Constants.side, height: Constants.side)
        let inset = Constants.outlineWidth / 2
        return UIGraphicsImageRenderer(bounds: bounds).image { _ in
            color.setFill()
            UIBezierPath(ovalIn: bounds).fill()
            let outline = UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
            outline.lineWidth = Constants.outlineWidth
            Constants.outline.setStroke()
            outline.stroke()
        }
        .withRenderingMode(.alwaysOriginal)
    }
}
