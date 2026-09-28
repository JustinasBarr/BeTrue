import Foundation

/// Where screens get photos. Hides the provider, the paging API and the offline copy.
nonisolated protocol PhotoRepository: Sendable {
    func curatedPhotos(page: Int) async throws -> PhotoPage
    func searchPhotos(matching query: String, filters: SearchFilters, page: Int) async throws -> PhotoPage
}

/// `PhotoRepository` over the Pexels REST API. Saves only the first page of the newest lists, and returns
/// that saved page when the network is down, rate limited or failing.
nonisolated final class PexelsPhotoRepository: PhotoRepository {
    private enum Constants {
        static let curatedPath = "v1/curated"
        static let searchPath = "v1/search"
        /// The API's maximum: every request counts against the hourly rate limit.
        static let pageSize = 80
        static let savedPage = 1
        /// Every search and filter saves its own list; older ones are removed past this many.
        static let savedListsPerPath = 20
    }

    private let network: any NetworkService
    private let store: any LocalStoring

    init(network: any NetworkService, store: any LocalStoring) {
        self.network = network
        self.store = store
    }

    func curatedPhotos(page: Int) async throws -> PhotoPage {
        try await photoPage(for: NetworkRequest(path: Constants.curatedPath, queryItems: pageItems(page)),
                            isSaved: page == Constants.savedPage)
    }

    func searchPhotos(matching query: String, filters: SearchFilters, page: Int) async throws -> PhotoPage {
        let items = [URLQueryItem(name: "query", value: query)] + filters.queryItems + pageItems(page)
        return try await photoPage(for: NetworkRequest(path: Constants.searchPath, queryItems: items),
                                   isSaved: page == Constants.savedPage)
    }

    private func photoPage(for request: NetworkRequest, isSaved: Bool) async throws -> PhotoPage {
        do {
            let data = try await network.data(for: request)
            let page = try await Self.decode(data)
            if isSaved { await save(data, for: request) }
            return page
        } catch let error as NetworkError where error.isTemporary {
            guard isSaved,
                  let saved = await store.savedData(forKey: request.cacheKey),
                  let page = try? await Self.decode(saved.data) else { throw error }
            return page.markedSaved(at: saved.savedAt)
        } catch is DecodingError {
            throw NetworkError.invalidResponse
        }
    }

    private func save(_ data: Data, for request: NetworkRequest) async {
        await store.save(data, forKey: request.cacheKey)
        await store.removeSavedData(withKeyPrefix: request.cacheKeyPrefix, keepingNewest: Constants.savedListsPerPath)
    }

    private func pageItems(_ page: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "page", value: String(page)),
         URLQueryItem(name: "per_page", value: String(Constants.pageSize))]
    }

    @concurrent
    private static func decode(_ data: Data) async throws -> PhotoPage {
        try JSONDecoder().decode(PhotoPage.self, from: data)
    }
}
