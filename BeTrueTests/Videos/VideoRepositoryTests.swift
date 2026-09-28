import Foundation
import Testing
@testable import BeTrue

struct VideoRepositoryTests {
    private enum Constants {
        static let pageSize = "80"
    }

    private let savedAt = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func popularRequestsThePageAndSavesIt() async throws {
        let network = try VideoTestNetwork(response: .success(pageData()))
        let store = VideoTestStore(savedAt: savedAt)
        let repository = PexelsVideoRepository(network: network, store: store)

        let page = try await repository.popularVideos(filters: VideoFilters(), page: 1)

        let expected = NetworkRequest(path: "v1/videos/popular", queryItems: [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per_page", value: Constants.pageSize)
        ])
        #expect(network.requests == [expected])
        #expect(store.values[expected.cacheKey] != nil)
        #expect(page.videos.map(\.id) == [1, 2])
        #expect(page.hasMore)
        #expect(page.savedAt == nil)
    }

    @Test func searchSendsTheQuery() async throws {
        let network = try VideoTestNetwork(response: .success(pageData()))
        let repository = PexelsVideoRepository(network: network, store: VideoTestStore(savedAt: savedAt))

        _ = try await repository.searchVideos(matching: "ocean waves", page: 2)

        let request = try #require(network.requests.first)
        #expect(request.path == "v1/videos/search")
        #expect(request.queryItems == [
            URLQueryItem(name: "query", value: "ocean waves"),
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "per_page", value: Constants.pageSize)
        ])
    }

    @Test(arguments: [NetworkError.offline, .rateLimited, .server(statusCode: 503)])
    func failureReturnsTheSavedPage(error: NetworkError) async throws {
        let network = try VideoTestNetwork(response: .success(pageData()))
        let store = VideoTestStore(savedAt: savedAt)
        let repository = PexelsVideoRepository(network: network, store: store)
        _ = try await repository.popularVideos(filters: VideoFilters(), page: 1)
        network.respond(with: .failure(error))

        let page = try await repository.popularVideos(filters: VideoFilters(), page: 1)

        #expect(page.videos.map(\.id) == [1, 2])
        #expect(page.savedAt == savedAt)
    }

    @Test func unauthorizedIsNotHiddenBySavedPage() async throws {
        let network = try VideoTestNetwork(response: .success(pageData()))
        let repository = PexelsVideoRepository(network: network, store: VideoTestStore(savedAt: savedAt))
        _ = try await repository.popularVideos(filters: VideoFilters(), page: 1)
        network.respond(with: .failure(.unauthorized))

        await #expect(throws: NetworkError.unauthorized) {
            try await repository.popularVideos(filters: VideoFilters(), page: 1)
        }
    }

    @Test func offlineWithNothingSavedThrows() async {
        let network = VideoTestNetwork(response: .failure(.offline))
        let repository = PexelsVideoRepository(network: network, store: VideoTestStore(savedAt: savedAt))

        await #expect(throws: NetworkError.offline) {
            try await repository.popularVideos(filters: VideoFilters(), page: 1)
        }
    }

    @Test func unreadableBodyIsAnInvalidResponseAndIsNotSaved() async {
        let network = VideoTestNetwork(response: .success(Data("<html>".utf8)))
        let store = VideoTestStore(savedAt: savedAt)
        let repository = PexelsVideoRepository(network: network, store: store)

        await #expect(throws: NetworkError.invalidResponse) {
            try await repository.popularVideos(filters: VideoFilters(), page: 1)
        }
        #expect(store.values.isEmpty)
    }

    private func pageData() throws -> Data {
        try VideoFixtures.pageData(videos: [VideoFixtures.video(id: 1), VideoFixtures.video(id: 2)], hasMore: true)
    }
}
