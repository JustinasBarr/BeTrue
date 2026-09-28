import Foundation
import Testing
@testable import BeTrue

@Suite struct URLSessionNetworkServiceTests {
    private let service = URLSessionNetworkService(baseURL: URL(string: "https://api.pexels.com/")!,
                                                   headers: ["Authorization": "test-key"])

    @Test func joinsThePathToTheBaseURL() throws {
        let request = try service.makeURLRequest(for: NetworkRequest(path: "v1/curated", queryItems: [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per_page", value: "40")
        ]))

        #expect(request.url?.absoluteString == "https://api.pexels.com/v1/curated?page=1&per_page=40")
    }

    @Test func joinsThePathToABaseURLWithoutTrailingSlash() throws {
        let service = URLSessionNetworkService(baseURL: URL(string: "https://api.pexels.com")!, headers: [:])

        let request = try service.makeURLRequest(for: NetworkRequest(path: "v1/curated"))

        #expect(request.url?.absoluteString == "https://api.pexels.com/v1/curated")
    }

    @Test func leavesOutAnEmptyQuery() throws {
        let request = try service.makeURLRequest(for: NetworkRequest(path: "v1/curated"))

        #expect(request.url?.query == nil)
    }

    @Test func encodesPlusAndAmpersandInsideAValue() throws {
        let request = try service.makeURLRequest(for: NetworkRequest(path: "v1/search", queryItems: [
            URLQueryItem(name: "query", value: "salt & pepper+oil"),
            URLQueryItem(name: "page", value: "1")
        ]))

        #expect(request.url?.query(percentEncoded: true) == "query=salt%20%26%20pepper%2Boil&page=1")
    }

    @Test(arguments: ["cats & dogs", "c++", "black+white", "a=b", "50% off", "tag#1", "café"])
    func serverReadsBackTheExactSearchText(text: String) throws {
        let request = try service.makeURLRequest(for: NetworkRequest(path: "v1/search", queryItems: [
            URLQueryItem(name: "query", value: text),
            URLQueryItem(name: "page", value: "1")
        ]))
        let query = try #require(request.url?.query(percentEncoded: true))

        #expect(serverDecodedValues(of: query) == [text, "1"])
    }

    @Test func sendsHeadersToTheBaseHost() throws {
        let request = try service.makeURLRequest(for: NetworkRequest(path: "v1/curated"))

        #expect(request.value(forHTTPHeaderField: "Authorization") == "test-key")
    }

    @Test func aPathCannotLeaveTheBaseHost() throws {
        let request = try service.makeURLRequest(for: NetworkRequest(path: "https://example.com/steal"))

        #expect(request.url?.host == "api.pexels.com")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "test-key")
    }

    @Test func sendsNoAuthorizationWithoutHeaders() throws {
        let service = URLSessionNetworkService(baseURL: URL(string: "https://api.pexels.com/")!, headers: [:])

        let request = try service.makeURLRequest(for: NetworkRequest(path: "v1/curated"))

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    /// Splits on "&" and "=", then decodes like a form-reading server, which turns "+" into a space.
    private func serverDecodedValues(of query: String) -> [String] {
        query.split(separator: "&").map { pair in
            let value = pair.split(separator: "=", maxSplits: 1).dropFirst().first ?? ""
            return value.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""
        }
    }
}
