import Foundation
import Testing
@testable import BeTrue

@MainActor
struct VideoFeedViewModelTests {
    private enum Constants {
        /// How many videos ahead of the one on screen the list keeps loaded.
        static let lookahead = 120
    }

    private let repository = VideoTestRepository()

    @Test func firstPageLoadsOnce() async throws {
        try repository.setResult(.success(VideoFixtures.page(1, ids: 1...20, hasMore: true)), forPage: 1)
        let viewModel = makeViewModel()

        await viewModel.loadFirstPage()
        await viewModel.loadFirstPage()

        #expect(repository.requestedPages == [1])
        #expect(viewModel.videos.map(\.id) == Array(1...20))
    }

    @Test func overlappingFirstLoadsRequestOnePage() async throws {
        try repository.setResult(.success(VideoFixtures.page(1, ids: 1...20, hasMore: true)), forPage: 1)
        let viewModel = makeViewModel()

        async let first: Void = viewModel.loadFirstPage()
        async let second: Void = viewModel.loadFirstPage()
        _ = await (first, second)

        #expect(repository.requestedPages == [1])
        #expect(viewModel.videos.count == 20)
    }

    @Test func nearTheEndLoadsTheNextPage() async throws {
        try repository.setResult(.success(VideoFixtures.page(1, ids: 1...160, hasMore: true)), forPage: 1)
        try repository.setResult(.success(VideoFixtures.page(2, ids: 161...180, hasMore: false)), forPage: 2)
        let viewModel = makeViewModel()
        await viewModel.loadFirstPage()
        try #require(viewModel.videos.count > Constants.lookahead)
        let firstNearEnd = viewModel.videos.count - Constants.lookahead

        await viewModel.loadMoreIfNeeded(after: viewModel.videos[firstNearEnd - 1])
        #expect(repository.requestedPages == [1])

        await viewModel.loadMoreIfNeeded(after: viewModel.videos[firstNearEnd])
        #expect(repository.requestedPages == [1, 2])
        #expect(viewModel.videos.map(\.id) == Array(1...180))

        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.videos.last))
        #expect(repository.requestedPages == [1, 2])
    }

    @Test func failedPageWaitsForRetry() async throws {
        try repository.setResult(.success(VideoFixtures.page(1, ids: 1...20, hasMore: true)), forPage: 1)
        let viewModel = makeViewModel()
        await viewModel.loadFirstPage()
        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.videos.last))
        #expect(viewModel.pages.phase == .failed(.offline))

        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.videos.last))
        #expect(repository.requestedPages == [1, 2])

        try repository.setResult(.success(VideoFixtures.page(2, ids: 21...40, hasMore: false)), forPage: 2)
        await viewModel.retry()
        #expect(repository.requestedPages == [1, 2, 2])
        #expect(viewModel.videos.count == 40)
    }

    @Test func savedFirstPageReportsWhenItWasSaved() async throws {
        let savedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let page = try VideoFixtures.page(1, ids: 1...20, hasMore: true).markedSaved(at: savedAt)
        repository.setResult(.success(page), forPage: 1)
        let viewModel = makeViewModel()

        await viewModel.loadFirstPage()

        #expect(viewModel.savedAt == savedAt)
    }

    private func makeViewModel() -> VideoFeedViewModel {
        VideoFeedViewModel(repository: repository)
    }
}
