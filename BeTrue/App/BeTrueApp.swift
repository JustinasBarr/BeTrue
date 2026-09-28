import Combine
import SwiftUI

@main
struct BeTrueApp: App {
    /// App-wide so the splash plays once per launch, not once per window or foreground.
    @State private var isShowingLaunchSplash = true
    @StateObject private var dependencies = DependencyHolder()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies.value)
                .launchSplash(isPresented: $isShowingLaunchSplash)
        }
    }
}

/// Keeps one `AppDependencies` for the app's lifetime.
private final class DependencyHolder: ObservableObject {
    let value = AppDependencies()
}
