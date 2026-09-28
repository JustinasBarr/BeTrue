import SwiftUI

/// Shapes. Nothing in the app has square corners: every control is a capsule, every surface that holds content
/// is a rounded rectangle, and every picture in a grid shares one radius, so the grid reads as one surface.
nonisolated enum Radius {
    static let tile: CGFloat = 12
    /// Floating panels, such as the search suggestions.
    static let panel: CGFloat = 16

    static var tileShape: RoundedRectangle { RoundedRectangle(cornerRadius: tile, style: .continuous) }
    static var panelShape: RoundedRectangle { RoundedRectangle(cornerRadius: panel, style: .continuous) }
    /// Buttons, chips, fields and banners: anything a single line tall.
    static var controlShape: Capsule { Capsule(style: .continuous) }
}
