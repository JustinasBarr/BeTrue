import SwiftUI

extension EnvironmentValues {
    /// Set once at the root by `dependencies(_:)`.
    var videoRepository: any VideoRepository {
        get { self[VideoRepositoryKey.self] }
        set { self[VideoRepositoryKey.self] = newValue }
    }
}

private struct VideoRepositoryKey: EnvironmentKey {
    static let defaultValue: any VideoRepository = MissingVideoRepository()
}

/// Stops a debug build when a screen is shown without the real repository.
nonisolated private struct MissingVideoRepository: VideoRepository {
    func popularVideos(filters: VideoFilters, page: Int) async throws -> VideoPage {
        try missing()
    }

    func searchVideos(matching query: String, page: Int) async throws -> VideoPage {
        try missing()
    }

    private func missing() throws -> VideoPage {
        assertionFailure("videoRepository is not set in the environment")
        throw NetworkError.invalidResponse
    }
}
