import Testing
@testable import BeTrue

private struct Item: Identifiable, Sendable {
    let id: Int
}

@Suite struct PaginatorTests {
    private enum Constants {
        static let pageSize = 40
        /// Shorter than a page, so the page has items both inside and outside it.
        static let lookahead = 12
    }

    @Test func startsIdleAndEmpty() {
        let pages = Paginator<Item>()

        #expect(pages.phase == .idle)
        #expect(pages.isEmpty)
    }

    @Test func beginReturnsTheFirstPageThenNothingWhileLoading() {
        var pages = Paginator<Item>()

        #expect(pages.beginNextPage() == 1)
        #expect(pages.phase == .loading)
        #expect(pages.beginNextPage() == nil)
    }

    @Test func completingAPageAdvancesToTheNext() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()

        pages.completePage(with: items(1...3), hasMore: true)

        #expect(pages.phase == .loaded)
        #expect(pages.items.map(\.id) == [1, 2, 3])
        #expect(pages.beginNextPage() == 2)
    }

    @Test func dropsItemsAlreadyShownOnAnEarlierPage() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()
        pages.completePage(with: items(1...3), hasMore: true)
        _ = pages.beginNextPage()

        pages.completePage(with: items(3...5) + items(4...4), hasMore: true)

        #expect(pages.items.map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test func finishesWhenTheServerHasNoMore() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()

        pages.completePage(with: items(1...3), hasMore: false)

        #expect(pages.phase == .finished)
        #expect(pages.beginNextPage() == nil)
    }

    @Test func finishesOnAnEmptyPage() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()

        pages.completePage(with: [], hasMore: true)

        #expect(pages.phase == .finished)
        #expect(pages.beginNextPage() == nil)
    }

    @Test func retryAfterAFailureAsksForTheSamePage() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()
        pages.completePage(with: items(1...3), hasMore: true)
        #expect(pages.beginNextPage() == 2)

        pages.failPage(with: .offline)

        #expect(pages.phase == .failed(.offline))
        #expect(pages.items.count == 3)
        #expect(pages.beginNextPage() == 2)
    }

    @Test func cancellingTheFirstPageReturnsToIdle() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()

        pages.cancelPage()

        #expect(pages.phase == .idle)
        #expect(pages.beginNextPage() == 1)
    }

    @Test func cancellingALaterPageKeepsTheItemsAndReleasesThePage() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()
        pages.completePage(with: items(1...3), hasMore: true)
        _ = pages.beginNextPage()

        pages.cancelPage()

        #expect(pages.phase == .loaded)
        #expect(pages.items.count == 3)
        #expect(pages.beginNextPage() == 2)
    }

    @Test func cancellingWhenNothingIsLoadingDoesNothing() {
        var pages = Paginator<Item>()
        _ = pages.beginNextPage()
        pages.failPage(with: .offline)

        pages.cancelPage()

        #expect(pages.phase == .failed(.offline))
    }

    @Test func isNearEndOnlyForTheLastItemsWithinTheLookahead() {
        var pages = Paginator<Item>(lookahead: Constants.lookahead)
        _ = pages.beginNextPage()
        pages.completePage(with: items(1...Constants.pageSize), hasMore: true)
        let firstNearEnd = Constants.pageSize - Constants.lookahead + 1

        #expect(pages.isNearEnd(Constants.pageSize))
        #expect(pages.isNearEnd(firstNearEnd))
        #expect(!pages.isNearEnd(firstNearEnd - 1))
        #expect(!pages.isNearEnd(1))
        #expect(!pages.isNearEnd(Constants.pageSize + 1))
    }

    private func items(_ ids: ClosedRange<Int>) -> [Item] {
        ids.map(Item.init)
    }
}
