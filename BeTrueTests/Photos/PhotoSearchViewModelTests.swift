import Foundation
import Testing
@testable import BeTrue

@MainActor
@Suite struct PhotoSearchViewModelTests {
    private enum Constants {
        static let recentSearchesKey = "recentSearches"
        static let recentSearchesLimit = 8
        static let savedAt = Date(timeIntervalSince1970: 1_700_000_000)
        /// Keeps live search out of tests that type and then press the Search key themselves.
        static let pauseLongerThanAnyTest = Duration.seconds(60)
    }

    private let repository = FakePhotoRepository()
    private let store = InMemoryLocalStore()

    @Test(arguments: ["", "   ", "\n\t "])
    func blankQueryIsIgnored(text: String) async {
        let viewModel = makeViewModel()
        viewModel.query = text

        await viewModel.submitSearch()

        #expect(repository.calls.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func submitSearchSearchesTheTrimmedQuery() async throws {
        repository.respond(with: try Fixtures.page(ids: [1, 2]))
        let viewModel = makeViewModel()
        viewModel.query = "  cats \n"

        await viewModel.submitSearch()

        #expect(repository.calls == [.search(query: "cats", page: 1)])
        #expect(viewModel.query == "cats")
        #expect(viewModel.submittedQuery == "cats")
        #expect(viewModel.photos.map(\.id) == [1, 2])
        #expect(viewModel.results.phase == .loaded)
    }

    @Test func aSlowOlderSearchNeverReplacesANewerOne() async throws {
        repository.holdResponses()
        let viewModel = makeViewModel()

        let slow = Task { await viewModel.search(for: "cats") }
        await repository.waitForCalls(1)
        let fast = Task { await viewModel.search(for: "dogs") }
        await repository.waitForCalls(2)
        repository.resume(.search(query: "dogs", page: 1), returning: try Fixtures.page(ids: [20, 21]))
        await fast.value
        repository.resume(.search(query: "cats", page: 1), returning: try Fixtures.page(ids: [10, 11]))
        await slow.value

        #expect(viewModel.photos.map(\.id) == [20, 21])
        #expect(viewModel.submittedQuery == "dogs")
        #expect(!viewModel.isReplacingResults)
    }

    @Test func previousResultsStayWhileANewSearchReplacesThem() async throws {
        repository.respond(with: try Fixtures.page(ids: [1, 2]))
        let viewModel = makeViewModel()
        await viewModel.search(for: "birds")
        repository.holdResponses()

        let search = Task { await viewModel.search(for: "cats") }
        await repository.waitForCalls(2)

        #expect(viewModel.isReplacingResults)
        #expect(viewModel.photos.map(\.id) == [1, 2])
        repository.resume(.search(query: "cats", page: 1), returning: try Fixtures.page(ids: [3]))
        await search.value
        #expect(!viewModel.isReplacingResults)
        #expect(viewModel.photos.map(\.id) == [3])
    }

    @Test func noPagingWhileANewSearchReplacesTheResults() async throws {
        repository.respond(with: try Fixtures.feedPage(1))
        let viewModel = makeViewModel()
        await viewModel.search(for: "birds")
        repository.holdResponses()
        let search = Task { await viewModel.search(for: "cats") }
        await repository.waitForCalls(2)

        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.photos.last))
        await viewModel.retry()

        #expect(repository.calls == [.search(query: "birds", page: 1), .search(query: "cats", page: 1)])
        repository.resume(.search(query: "cats", page: 1), returning: try Fixtures.page(ids: [3]))
        await search.value
    }

    @Test func loadMoreIfNeededAsksForTheNextPageOfTheSameQuery() async throws {
        repository.respond(with: try Fixtures.feedPage(1))
        let viewModel = makeViewModel()
        await viewModel.search(for: "cats")
        repository.respond(with: try Fixtures.feedPage(2))

        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.photos.last))

        #expect(repository.calls.last == .search(query: "cats", page: 2))
        #expect(viewModel.photos.count == 2 * Fixtures.defaultPageSize)
    }

    @Test func recentSearchesAreNewestFirstWithoutCaseInsensitiveDuplicates() async throws {
        repository.respond(with: try Fixtures.page(ids: [1]))
        let viewModel = makeViewModel()

        for text in ["cats", "dogs", "Cats"] {
            await viewModel.search(for: text)
        }

        #expect(viewModel.recentSearches == ["Cats", "dogs"])
    }

    @Test func recentSearchesKeepOnlyTheLatest() async {
        let viewModel = makeViewModel()
        let searches = (1...Constants.recentSearchesLimit + 2).map { "query \($0)" }

        for text in searches {
            await viewModel.search(for: text)
        }

        #expect(viewModel.recentSearches == Array(searches.reversed().prefix(Constants.recentSearchesLimit)))
    }

    @Test func recentSearchesAreSavedAndLoadedBack() async throws {
        let viewModel = makeViewModel()
        await viewModel.search(for: "cats")
        await viewModel.search(for: "dogs")

        let relaunched = makeViewModel()
        await relaunched.loadRecentSearches()

        #expect(relaunched.recentSearches == ["dogs", "cats"])
        let saved = try #require(await store.savedData(forKey: Constants.recentSearchesKey))
        #expect(try JSONDecoder().decode([String].self, from: saved.data) == ["dogs", "cats"])
    }

    @Test func removingARecentSearchIsSaved() async {
        let viewModel = makeViewModel()
        await viewModel.search(for: "cats")
        await viewModel.search(for: "dogs")

        await viewModel.removeRecentSearch("cats")

        #expect(viewModel.recentSearches == ["dogs"])
        let relaunched = makeViewModel()
        await relaunched.loadRecentSearches()
        #expect(relaunched.recentSearches == ["dogs"])
    }

    @Test func failedSearchStillBecomesARecentSearch() async {
        repository.fail(with: NetworkError.offline)
        let viewModel = makeViewModel()

        await viewModel.search(for: "cats")

        #expect(viewModel.results.phase == .failed(.offline))
        #expect(viewModel.recentSearches == ["cats"])
    }

    @Test func cancelSearchClearsTheSearch() async throws {
        repository.respond(with: try Fixtures.page(ids: [1]).markedSaved(at: Constants.savedAt))
        let viewModel = makeViewModel()
        await viewModel.search(for: "cats")
        #expect(viewModel.savedAt == Constants.savedAt)

        viewModel.cancelSearch()

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.photos.isEmpty)
        #expect(viewModel.results.phase == .idle)
        #expect(!viewModel.isReplacingResults)
        #expect(viewModel.savedAt == nil)
        #expect(viewModel.recentSearches == ["cats"])
    }

    @Test func cancelSearchDropsAnAnswerStillOnItsWay() async throws {
        repository.holdResponses()
        let viewModel = makeViewModel()
        let search = Task { await viewModel.search(for: "cats") }
        await repository.waitForCalls(1)

        viewModel.cancelSearch()
        repository.resume(.search(query: "cats", page: 1), returning: try Fixtures.page(ids: [1]))
        await search.value

        #expect(viewModel.photos.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)
    }

    @Test func typingSearchesOnceTypingPauses() async throws {
        repository.respond(with: try Fixtures.page(ids: [1, 2]))
        let viewModel = makeViewModel(typingPause: .zero)

        viewModel.query = "c"
        viewModel.query = "ca"
        viewModel.query = "cats "
        await waitUntil { viewModel.results.phase == .loaded }

        #expect(repository.calls == [.search(query: "cats", page: 1)])
        #expect(viewModel.submittedQuery == "cats")
        #expect(viewModel.query == "cats ", "Typing is never rewritten under the cursor")
        #expect(viewModel.recentSearches.isEmpty, "Only searches the user commits to are remembered")
    }

    @Test func clearingTheFieldReturnsToCuratedPhotos() async throws {
        repository.respond(with: try Fixtures.page(ids: [1]))
        let viewModel = makeViewModel(typingPause: .zero)
        await viewModel.search(for: "cats")

        viewModel.query = ""

        #expect(!viewModel.isShowingResults)
        #expect(viewModel.photos.isEmpty)
        #expect(viewModel.results.phase == .idle)
    }

    @Test func theSearchKeyRemembersALiveSearchWithoutLoadingItAgain() async throws {
        repository.respond(with: try Fixtures.page(ids: [1]))
        let viewModel = makeViewModel(typingPause: .zero)
        viewModel.query = "cats"
        await waitUntil { viewModel.results.phase == .loaded }

        await viewModel.submitSearch()

        #expect(repository.calls == [.search(query: "cats", page: 1)])
        #expect(viewModel.recentSearches == ["cats"])
    }

    private func makeViewModel(typingPause: Duration = Constants.pauseLongerThanAnyTest) -> PhotoSearchViewModel {
        PhotoSearchViewModel(repository: repository, store: store, typingPause: typingPause)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        while !condition() { await Task.yield() }
    }
}
