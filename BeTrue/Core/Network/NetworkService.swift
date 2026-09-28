import Foundation

nonisolated protocol NetworkService: Sendable {
    func data(for request: NetworkRequest) async throws -> Data
}

/// Sends the default headers (such as an API key) only to the base URL's host.
nonisolated final class URLSessionNetworkService: NetworkService {
    private let baseURL: URL
    private let headers: [String: String]
    private let session: URLSession

    init(baseURL: URL, headers: [String: String], session: URLSession = .shared) {
        self.baseURL = baseURL
        self.headers = headers
        self.session = session
    }

    func data(for request: NetworkRequest) async throws -> Data {
        let urlRequest = try makeURLRequest(for: request)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw NetworkError(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        if let error = NetworkError(statusCode: httpResponse.statusCode) { throw error }
        return data
    }

    func makeURLRequest(for request: NetworkRequest) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.path),
                                             resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidResponse
        }
        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
            // URLComponents leaves "+" unescaped in values, and servers read it as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components.url else { throw NetworkError.invalidResponse }
        var urlRequest = URLRequest(url: url)
        if url.host == baseURL.host {
            headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        }
        return urlRequest
    }
}
