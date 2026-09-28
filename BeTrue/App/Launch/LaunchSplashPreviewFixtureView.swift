//
//  LaunchSplashPreviewFixtureView.swift
//  BeTrue
//

#if DEBUG
import SwiftUI

/// DEBUG ONLY, never app content. The live gallery depends on the network and is mostly black
/// while it loads, so launch-splash captures and UI tests put this fixed content under the splash
/// with the launch argument `-LaunchSplashPreviewFixture YES`. Release builds compile it out.
///
/// The tiles are flat colours, like photo placeholders before their images load, and the toggle
/// gives the touch-blocking test something to tap.
struct LaunchSplashPreviewFixtureView: View {
    private static let tileColors = [
        "#C9A27E", "#2F4858", "#8FA876", "#D96C4F", "#5B6C8F", "#E3C567",
        "#7A4E6D", "#3E7C74", "#B8B2A7", "#1F2A36", "#A85C3B", "#6F9FBF"
    ]
    private static let tileCount = 36

    @State private var isOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEBUG PREVIEW FIXTURE")
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.ink)
                .foregroundColor(Palette.ground)
            Text("Stand-in for launch splash captures. Not app content.")
                .font(.footnote)
                .foregroundColor(Palette.inkSecondary)
            Button(isOn ? "Fixture toggle: on" : "Fixture toggle: off") { isOn.toggle() }
                .buttonStyle(.bordered)
                .tint(Palette.ink)
                .accessibilityIdentifier("previewFixtureToggle")
                .accessibilityValue(isOn ? "on" : "off")
            // The tiles fill the rest of the screen and are cut off at its bottom, so the badge
            // and the toggle above them always stay on screen.
            Color.clear
                .overlay(alignment: .top) { tiles }
                .clipped()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.ground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("previewFixture")
    }

    private var tiles: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(0..<Self.tileCount, id: \.self) { index in
                (Color(hex: Self.tileColors[index % Self.tileColors.count]) ?? Palette.fill)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(alignment: .bottomLeading) {
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(.white)
                            .padding(6)
                    }
            }
        }
    }
}
#endif
