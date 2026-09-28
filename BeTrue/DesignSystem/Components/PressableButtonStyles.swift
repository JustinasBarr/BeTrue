import SwiftUI

/// The brand's solid action: an ink capsule with ground text.
struct SolidButtonStyle: ButtonStyle {
    private enum Constants {
        static let height: CGFloat = 44
        static let horizontalPadding: CGFloat = 20
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.callout)
            .foregroundColor(Palette.ground)
            .padding(.horizontal, Constants.horizontalPadding)
            .frame(minHeight: Constants.height)
            .background(Palette.ink, in: Radius.controlShape)
            .contentShape(Radius.controlShape)
            .modifier(PressFeedback(isPressed: configuration.isPressed))
    }
}

/// A plain control that still acknowledges the press.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .modifier(PressFeedback(isPressed: configuration.isPressed))
    }
}

/// Grid tiles dim instead of shrinking, so the grid's columns stay straight.
struct TileButtonStyle: ButtonStyle {
    private enum Constants {
        static let pressedOpacity = 0.8
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Constants.pressedOpacity : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

private struct PressFeedback: ViewModifier {
    private enum Constants {
        static let pressedScale: CGFloat = 0.96
        static let pressedOpacity = 0.7
    }

    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? Constants.pressedScale : 1)
            .opacity(isPressed && reduceMotion ? Constants.pressedOpacity : 1)
            .animation(Motion.quick, value: isPressed)
    }
}
