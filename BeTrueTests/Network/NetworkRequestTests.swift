import Foundation
import Testing
@testable import BeTrue

@Suite struct NetworkRequestTests {
    @Test func cacheKeyIgnoresQueryItemOrder() {
        let first = NetworkRequest(path: "v1/search", queryItems: [
            URLQueryItem(name: "query", value: "cats"),
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "per_page", value: "40")
        ])
        let second = NetworkRequest(path: "v1/search", queryItems: [
            URLQueryItem(name: "per_page", value: "40"),
            URLQueryItem(name: "query", value: "cats"),
            URLQueryItem(name: "page", value: "2")
        ])

        #expect(first.cacheKey == second.cacheKey)
        #expect(first.cacheKey == "v1/search?page=2&per_page=40&query=cats")
    }

    @Test func cacheKeyTellsDifferentPagesApart() {
        let pageOne = NetworkRequest(path: "v1/curated", queryItems: [URLQueryItem(name: "page", value: "1")])
        let pageTwo = NetworkRequest(path: "v1/curated", queryItems: [URLQueryItem(name: "page", value: "2")])

        #expect(pageOne.cacheKey != pageTwo.cacheKey)
    }

    @Test func cacheKeyWithoutQueryIsThePath() {
        #expect(NetworkRequest(path: "v1/curated").cacheKey == "v1/curated")
    }

    @Test func cacheKeyKeepsItemsWithoutValue() {
        let request = NetworkRequest(path: "v1/curated", queryItems: [URLQueryItem(name: "flag", value: nil)])

        #expect(request.cacheKey == "v1/curated?flag=")
    }
}
