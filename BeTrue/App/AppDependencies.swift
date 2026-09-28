import SwiftUI

/// Long-lived services created once at launch. Holds services, never view models.
final class AppDependencies {
    private enum Constants {
        static let authorizationHeader = "Authorization"
        /// A weak connection falls back to the saved copy after this, instead of the system's 60 seconds.
        static let requestTimeout: TimeInterval = 15
    }

    let configuration: AppConfiguration
    let imageLoader: any ImageLoading
    let networkMonitor: NetworkMonitor
    let photoRepository: any PhotoRepository
    let store: any LocalStoring
    let videoRepository: any VideoRepository

    var hasAPIKey: Bool { configuration.apiKey != nil }

    init(configuration: AppConfiguration = .load()) {
        self.configuration = configuration
        let network = URLSessionNetworkService(baseURL: configuration.apiBaseURL,
                                               headers: [Constants.authorizationHeader: configuration.apiKey ?? ""],
                                               session: Self.apiSession())
        let store = LocalStore()
        self.store = store
        imageLoader = ImageLoader()
        networkMonitor = NetworkMonitor()
        photoRepository = PexelsPhotoRepository(network: network, store: store)
        videoRepository = PexelsVideoRepository(network: network, store: store)
    }

    private static func apiSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Constants.requestTimeout
        #if DEBUG
        configuration.simulateOfflineIfRequested()
        #endif
        return URLSession(configuration: configuration)
    }
}

extension View {
    func dependencies(_ dependencies: AppDependencies) -> some View {
        environment(\.imageLoader, dependencies.imageLoader)
            .environment(\.photoRepository, dependencies.photoRepository)
            .environment(\.localStore, dependencies.store)
            .environment(\.videoRepository, dependencies.videoRepository)
            .environmentObject(dependencies.networkMonitor)
    }
}
