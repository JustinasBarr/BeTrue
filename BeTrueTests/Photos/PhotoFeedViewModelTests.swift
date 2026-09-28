import Combine
import Foundation
import Testing
@testable import BeTrue

@MainActor
@Suite struct PhotoFeedViewModelTests {
    private enum Constants {
        static let pageSize = Fixtures.defaultPageSize
        /// How many photos ahead of the one on screen the feed keeps loaded.
        static let lookahead = 120
        /// Longer than the lookahead, so its first photos are not near the end.
        static let longPageSize = lookahead + pageSize
        static let savedAt = Date(timeIntervalSince1970: 1_700_000_000)
    }

    private let repository = FakePhotoRepository()
    private let onlineUpdates = PassthroughSubject<Bool, Never>()

    @Test func loadFirstPageLoadsOnlyOnce() async throws {
        repository.respond(with: try Fixtures.feedPage(1))
        let viewModel = makeViewModel()

        await viewModel.loadFirstPage()
        await viewModel.loadFirstPage()

        #expect(repository.calls == [.curated(page: 1)])
        #expect(viewModel.photos.count == Constants.pageSize)
        #expect(viewModel.pages.phase == .loaded)
    }

    @Test func loadMoreIfNeededWaitsForTheEndOfTheList() async throws {
        respondWithFeedPages(size: Constants.longPageSize)
        let viewModel = makeViewModel()
        await viewModel.loadFirstPage()
        try #require(viewModel.photos.count == Constants.longPageSize)
        let firstNearEnd = Constants.longPageSize - Constants.lookahead

        await viewModel.loadMoreIfNeeded(after: viewModel.photos[firstNearEnd - 1])
        #expect(repository.calls == [.curated(page: 1)])

        await viewModel.loadMoreIfNeeded(after: viewModel.photos[firstNearEnd])
        #expect(repository.calls == [.curated(page: 1), .curated(page: 2)])
        #expect(viewModel.photos.count == 2 * Constants.longPageSize)
    }

    @Test func failureShowsTheErrorAndRetryRecovers() async throws {
        repository.fail(with: NetworkError.offline)
        let viewModel = makeViewModel()

        await viewModel.loadFirstPage()
        #expect(viewModel.pages.phase == .failed(.offline))

        repository.respond(with: try Fixtures.feedPage(1))
        await viewModel.retry()

        #expect(viewModel.pages.phase == .loaded)
        #expect(viewModel.photos.count == Constants.pageSize)
        #expect(repository.calls == [.curated(page: 1), .curated(page: 1)])
    }

    @Test func scrollingDoesNotRetryAFailedPage() async throws {
        repository.respond(with: try Fixtures.feedPage(1))
        let viewModel = makeViewModel()
        await viewModel.loadFirstPage()
        repository.fail(with: NetworkError.server(statusCode: 500))
        let last = try #require(viewModel.photos.last)

        await viewModel.loadMoreIfNeeded(after: last)
        await viewModel.loadMoreIfNeeded(after: last)

        #expect(viewModel.pages.phase == .failed(.server(statusCode: 500)))
        #expect(repository.calls == [.curated(page: 1), .curated(page: 2)])
    }

    @Test func unexpectedErrorIsAnInvalidResponse() async {
        repository.fail(with: CocoaError(.fileReadCorruptFile))
        let viewModel = makeViewModel()

        await viewModel.loadFirstPage()

        #expect(viewModel.pages.phase == .failed(.invalidResponse))
    }

    @Test func cancelledFirstPageCanLoadAgain() async throws {
        repository.holdResponses()
        let viewModel = makeViewModel()
        let load = Task { await viewModel.loadFirstPage() }
        await repository.waitForCalls(1)

        repository.resume(.curated(page: 1), throwing: CancellationError())
        await load.value

        #expect(viewModel.pages.phase == .idle)
        let reload = Task { await viewModel.loadFirstPage() }
        await repository.waitForCalls(2)
        repository.resume(.curated(page: 1), returning: try Fixtures.feedPage(1))
        await reload.value
        #expect(viewModel.photos.count == Constants.pageSize)
    }

    @Test func refreshReplacesThePhotosAndStartsPagingAgain() async throws {
        respondWithFeedPages()
        let viewModel = makeViewModel()
        await viewModel.loadFirstPage()
        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.photos.last))
        let replacement = Array(1001...1040)
        repository.respond(with: try Fixtures.page(ids: replacement))

        await viewModel.refresh()

        #expect(viewModel.photos.map(\.id) == replacement)
        respondWithFeedPages()
        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.photos.last))
        #expect(repository.calls.last == .curated(page: 2))
    }

    @Test func failedRefreshKeepsThePhotosOnScreen() async throws {
        repository.respond(with: try Fixtures.feedPage(1))
        let viewModel = makeViewModel()
        await viewModel.loadFirstPage()
        repository.fail(with: NetworkError.offline)

        await viewModel.refresh()

        #expect(viewModel.photos.count == Constants.pageSize)
        #expect(viewModel.pages.phase == .loaded)
    }

    @Test func refreshDropsAPageRequestedForTheOldList() async throws {
        repository.respond(with: try Fixtures.feedPage(1))
        let viewModel = makeViewModel()
        await viewModel.loadFirstPage()
        repository.holdResponses()
        let replacement = Array(1001...1040)
        let last = try #require(viewModel.photos.last)

        let loadMore = Task { await viewModel.loadMoreIfNeeded(after: last) }
        await repository.waitForCalls(2)
        let refresh = Task { await viewModel.refresh() }
        await repository.waitForCalls(3)
        repository.resume(.curated(page: 1), returning: try Fixtures.page(ids: replacement))
        await refresh.value
        repository.resume(.curated(page: 2), returning: try Fixtures.feedPage(2))
        await loadMore.value

        #expect(viewModel.photos.map(\.id) == replacement)
        #expect(viewModel.pages.phase == .loaded)
    }

    @Test func savedAtFollowsTheShownPage() async throws {
        repository.respond(with: try Fixtures.feedPage(1).markedSaved(at: Constants.savedAt))
        let viewModel = makeViewModel()

        await viewModel.loadFirstPage()
        #expect(viewModel.savedAt == Constants.savedAt)

        repository.respond(with: try Fixtures.feedPage(1))
        await viewModel.refresh()
        #expect(viewModel.savedAt == nil)
    }

    @Test func reconnectingRetriesAFailedPage() async throws {
        let viewModel = makeViewModel()
        onlineUpdates.send(true)
        repository.fail(with: NetworkError.offline)
        await viewModel.loadFirstPage()
        onlineUpdates.send(false)
        repository.respond(with: try Fixtures.feedPage(1))

        onlineUpdates.send(true)
        await viewModel.$pages.firstValue { $0.phase == .loaded }

        #expect(viewModel.photos.count == Constants.pageSize)
        #expect(repository.calls == [.curated(page: 1), .curated(page: 1)])
    }

    @Test func reconnectingRefreshesAnOfflineCopy() async throws {
        let viewModel = makeViewModel()
        onlineUpdates.send(true)
        repository.respond(with: try Fixtures.feedPage(1).markedSaved(at: Constants.savedAt))
        await viewModel.loadFirstPage()
        onlineUpdates.send(false)
        repository.respond(with: try Fixtures.feedPage(1))

        onlineUpdates.send(true)
        await viewModel.$savedAt.firstValue { $0 == nil }

        #expect(repository.calls == [.curated(page: 1), .curated(page: 1)])
    }

    private func makeViewModel() -> PhotoFeedViewModel {
        PhotoFeedViewModel(repository: repository, onlineUpdates: onlineUpdates.eraseToAnyPublisher())
    }

    private func respondWithFeedPages(size: Int = Constants.pageSize) {
        repository.respond { call in
            guard case .curated(let page) = call else { throw NetworkError.invalidResponse }
            return try Fixtures.feedPage(page, size: size)
        }
    }
}
