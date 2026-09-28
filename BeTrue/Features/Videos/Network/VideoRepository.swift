import Foundation

nonisolated protocol VideoRepository: Sendable {
    func popularVideos(filters: VideoFilters, page: Int) async throws -> VideoPage
    func searchVideos(matching query: String, page: Int) async throws -> VideoPage
}

/// Saves only the first page of the newest lists, and returns that saved page when the network is down,
/// rate limited or failing.
nonisolated final class PexelsVideoRepository: VideoRepository {
    private enum Constants {
        static let popularPath = "v1/videos/popular"
        static let searchPath = "v1/videos/search"
        /// The API's maximum. Still frames load per tile, so a longer page costs no images.
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

    func popularVideos(filters: VideoFilters, page: Int) async throws -> VideoPage {
        let items = filters.queryItems + pageItems(page)
        return try await videoPage(for: NetworkRequest(path: Constants.popularPath, queryItems: items),
                                   isSaved: page == Constants.savedPage)
    }

    func searchVideos(matching query: String, page: Int) async throws -> VideoPage {
        let items = [URLQueryItem(name: "query", value: query)] + pageItems(page)
        return try await videoPage(for: NetworkRequest(path: Constants.searchPath, queryItems: items),
                                   isSaved: page == Constants.savedPage)
    }

    private func videoPage(for request: NetworkRequest, isSaved: Bool) async throws -> VideoPage {
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
    private static func decode(_ data: Data) async throws -> VideoPage {
        try JSONDecoder().decode(VideoPage.self, from: data)
    }
}
