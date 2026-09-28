import Foundation

nonisolated struct NetworkRequest: Hashable, Sendable {
    let path: String
    let queryItems: [URLQueryItem]

    /// Identifies the saved response offline, whatever the order of the query items.
    var cacheKey: String {
        let query = queryItems
            .map { "\($0.name)=\($0.value ?? "")" }
            .sorted()
            .joined(separator: "&")
        return query.isEmpty ? path : cacheKeyPrefix + query
    }

    /// How the cache key of every request to this path with a query starts, so old ones can be removed together.
    var cacheKeyPrefix: String { "\(path)?" }

    init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }
}
