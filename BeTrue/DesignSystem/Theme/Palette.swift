import SwiftUI
import UIKit

/// Pure black and white; every other shade is ink at a fixed opacity.
enum Palette {
    static let ground = Color(uiColor: .adaptive(dark: .black, light: .white))
    static let ink = Color(uiColor: .adaptive(dark: .white, light: .black))
    static let inkSecondary = ink.opacity(0.6)
    /// Hints and disabled text.
    static let inkTertiary = ink.opacity(0.38)
    /// Image placeholders and quiet fills.
    static let fill = ink.opacity(0.08)
    static let hairline = ink.opacity(0.14)
}

private extension UIColor {
    /// Nonisolated because UIKit resolves the colour off the main thread; a main-actor provider is checked every call.
    nonisolated static func adaptive(dark: UIColor, light: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .light ? light : dark }
    }
}

extension Color {
    /// A colour from a hex string such as "#978E82"; nil when the string is not a 6-digit hex colour.
    init?(hex: String?) {
        guard let hex, let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16),
              hex.count >= 6 else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
