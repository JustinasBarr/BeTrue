import SwiftUI

extension EnvironmentValues {
    /// Set once at the root by `dependencies(_:)`.
    var photoRepository: any PhotoRepository {
        get { self[PhotoRepositoryKey.self] }
        set { self[PhotoRepositoryKey.self] = newValue }
    }
}

private struct PhotoRepositoryKey: EnvironmentKey {
    static let defaultValue: any PhotoRepository = MissingPhotoRepository()
}

/// Stops a debug build when a screen is shown without the real repository.
nonisolated private struct MissingPhotoRepository: PhotoRepository {
    func curatedPhotos(page: Int) async throws -> PhotoPage {
        try missing()
    }

    func searchPhotos(matching query: String, filters: SearchFilters, page: Int) async throws -> PhotoPage {
        try missing()
    }

    private func missing() throws -> PhotoPage {
        assertionFailure("photoRepository is not set in the environment")
        throw NetworkError.invalidResponse
    }
}
