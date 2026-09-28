import Foundation

nonisolated enum NetworkError: Error, Equatable, Sendable {
    case offline
    case unauthorized
    case rateLimited
    case server(statusCode: Int)
    case invalidResponse

    private enum StatusCode {
        static let success = 200..<300
        static let unauthorized = 401
        static let forbidden = 403
        static let tooManyRequests = 429
    }

    /// Failures that may pass on their own, where an older saved copy beats an error screen.
    var isTemporary: Bool {
        switch self {
        case .offline, .rateLimited, .server: true
        case .unauthorized, .invalidResponse: false
        }
    }

    init(_ error: URLError) {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .timedOut:
            self = .offline
        default:
            self = .server(statusCode: error.errorCode)
        }
    }

    init?(statusCode: Int) {
        switch statusCode {
        case StatusCode.success: return nil
        case StatusCode.unauthorized, StatusCode.forbidden: self = .unauthorized
        case StatusCode.tooManyRequests: self = .rateLimited
        default: self = .server(statusCode: statusCode)
        }
    }
}
