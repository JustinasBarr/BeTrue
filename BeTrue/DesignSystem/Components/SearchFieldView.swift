import SwiftUI

/// The brand search field: glyph, text, clear button, and a Cancel button while it is in use.
struct SearchFieldView: View {
    private enum Constants {
        static let height: CGFloat = 44
        static let horizontalPadding: CGFloat = 12
        static let glyphSpacing: CGFloat = 8
        static let cancelSpacing: CGFloat = 16
    }

    @Binding var text: String
    let prompt: String
    /// Owned by the screen, so it can show recent searches while the field has focus.
    var isFocused: FocusState<Bool>.Binding
    /// True while results are shown, so Cancel stays available after the keyboard closes.
    let isActive: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Constants.cancelSpacing) {
            field
            if showsCancel {
                Button("Cancel", action: cancel)
                    .font(Typography.callout)
                    .foregroundColor(Palette.ink)
                    .buttonStyle(PressableButtonStyle())
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    .accessibilityIdentifier("searchCancel")
            }
        }
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: showsCancel)
    }

    private var showsCancel: Bool { isFocused.wrappedValue || isActive }

    private var field: some View {
        HStack(spacing: Constants.glyphSpacing) {
            Image(systemName: "magnifyingglass")
                .font(Typography.callout)
                .foregroundColor(Palette.inkSecondary)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(prompt).foregroundColor(Palette.inkSecondary))
                .font(Typography.body)
                .foregroundColor(Palette.ink)
                .tint(Palette.ink)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)
                .accessibilityLabel(prompt)
                .accessibilityIdentifier("searchField")
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Palette.inkSecondary)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Clear text")
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(height: Constants.height)
        .background(Palette.fill, in: Radius.controlShape)
        .contentShape(Radius.controlShape)
        .onTapGesture { isFocused.wrappedValue = true }
    }

    private func cancel() {
        isFocused.wrappedValue = false
        onCancel()
    }
}
