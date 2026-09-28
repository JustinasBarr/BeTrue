import SwiftUI

/// A round button that floats over content on the same glass surface as the tab bar.
struct FloatingRoundButtonView<Glyph: View>: View {
    private enum Constants {
        static var diameter: CGFloat { 52 }
    }

    let action: () -> Void
    @ViewBuilder let glyph: () -> Glyph

    var body: some View {
        Button(action: action) {
            glyph()
                .foregroundColor(Palette.ink)
                .frame(width: Constants.diameter, height: Constants.diameter)
                .glassSurface(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
