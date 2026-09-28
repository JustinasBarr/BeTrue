import Foundation
import Testing
@testable import BeTrue

@Suite struct PexelsPhotoRepositoryTests {
    private enum Constants {
        static let pageSize = "80"
    }

    private let network = FakeNetworkService()
    private let store = LocalStore(inMemory: true)
    private let curatedPageOne = NetworkRequest(path: "v1/curated", queryItems: [
        URLQueryItem(name: "page", value: "1"),
        URLQueryItem(name: "per_page", value: Constants.pageSize)
    ])

    @Test func curatedAsksForThePageAndSavesTheResponse() async throws {
        let data = Data(Fixtures.pageJSON(ids: [1, 2]).utf8)
        network.respond(with: .success(data))

        let page = try await makeRepository().curatedPhotos(page: 1)

        #expect(page.photos.map(\.id) == [1, 2])
        #expect(page.savedAt == nil)
        #expect(network.requests == [curatedPageOne])
        #expect(await store.savedData(forKey: curatedPageOne.cacheKey)?.data == data)
    }

    @Test func searchSendsTheQueryAndSavesUnderItsOwnKey() async throws {
        let data = Data(Fixtures.pageJSON(ids: [7]).utf8)
        network.respond(with: .success(data))
        let expected = NetworkRequest(path: "v1/search", queryItems: [
            URLQueryItem(name: "query", value: "cats & dogs"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per_page", value: Constants.pageSize)
        ])

        _ = try await makeRepository().searchPhotos(matching: "cats & dogs", filters: SearchFilters(), page: 1)

        #expect(network.requests == [expected])
        #expect(await store.savedData(forKey: expected.cacheKey)?.data == data)
        #expect(await store.savedData(forKey: curatedPageOne.cacheKey) == nil)
    }

    @Test(arguments: [NetworkError.offline, .rateLimited, .server(statusCode: 503)])
    func failureFallsBackToTheSavedPage(error: NetworkError) async throws {
        let repository = makeRepository()
        network.respond(with: .success(Data(Fixtures.pageJSON(ids: [1, 2]).utf8)))
        _ = try await repository.curatedPhotos(page: 1)
        network.respond(with: .failure(error))

        let page = try await repository.curatedPhotos(page: 1)

        #expect(page.photos.map(\.id) == [1, 2])
        let saved = try #require(await store.savedData(forKey: curatedPageOne.cacheKey))
        #expect(page.savedAt == saved.savedAt)
    }

    @Test func unauthorizedNeverShowsTheSavedPage() async throws {
        let repository = makeRepository()
        network.respond(with: .success(Data(Fixtures.pageJSON(ids: [1, 2]).utf8)))
        _ = try await repository.curatedPhotos(page: 1)
        network.respond(with: .failure(NetworkError.unauthorized))

        await #expect(throws: NetworkError.unauthorized) {
            try await repository.curatedPhotos(page: 1)
        }
    }

    @Test func failureWithoutASavedPageRethrows() async {
        network.respond(with: .failure(NetworkError.offline))

        await #expect(throws: NetworkError.offline) {
            try await makeRepository().curatedPhotos(page: 1)
        }
    }

    @Test func savedPageIsOnlyUsedForTheSameRequest() async throws {
        let repository = makeRepository()
        network.respond(with: .success(Data(Fixtures.pageJSON(ids: [1, 2]).utf8)))
        _ = try await repository.curatedPhotos(page: 1)
        network.respond(with: .failure(NetworkError.offline))

        await #expect(throws: NetworkError.offline) {
            try await repository.curatedPhotos(page: 2)
        }
    }

    @Test func invalidJSONIsAnInvalidResponseAndIsNotSaved() async {
        network.respond(with: .success(Data("<html>Bad gateway</html>".utf8)))

        await #expect(throws: NetworkError.invalidResponse) {
            try await makeRepository().curatedPhotos(page: 1)
        }
        #expect(await store.savedData(forKey: curatedPageOne.cacheKey) == nil)
    }

    private func makeRepository() -> PexelsPhotoRepository {
        PexelsPhotoRepository(network: network, store: store)
    }
}
