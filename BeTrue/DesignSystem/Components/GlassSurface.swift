import SwiftUI

extension View {
    /// The surface of controls that float over photos: the tab bar and the appearance button.
    func glassSurface(in shape: some Shape) -> some View {
        modifier(GlassSurface(shape: shape))
    }
}

private struct GlassSurface<SurfaceShape: Shape>: ViewModifier {
    private enum Constants {
        static var hairlineWidth: CGFloat { 1 }
        static var shadowOpacity: Double { 0.12 }
        static var shadowRadius: CGFloat { 16 }
        static var shadowOffset: CGFloat { 6 }
    }

    let shape: SurfaceShape

    func body(content: Content) -> some View {
        // The one approved availability check: Liquid Glass where the system has it, a material before.
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Palette.hairline, lineWidth: Constants.hairlineWidth))
                .shadow(color: .black.opacity(Constants.shadowOpacity),
                        radius: Constants.shadowRadius, y: Constants.shadowOffset)
        }
    }
}
