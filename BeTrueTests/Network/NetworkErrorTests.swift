import Foundation
import Testing
@testable import BeTrue

@Suite struct NetworkErrorTests {
    @Test(arguments: [
        URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
        .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut
    ])
    func connectionErrorsMeanOffline(code: URLError.Code) {
        #expect(NetworkError(URLError(code)) == .offline)
    }

    @Test func otherURLErrorsKeepTheirCode() {
        let error = URLError(.badServerResponse)

        #expect(NetworkError(error) == .server(statusCode: URLError.Code.badServerResponse.rawValue))
    }

    @Test(arguments: [200, 201, 204, 299])
    func successStatusIsNoError(statusCode: Int) {
        #expect(NetworkError(statusCode: statusCode) == nil)
    }

    @Test(arguments: [401, 403])
    func rejectedKeyIsUnauthorized(statusCode: Int) {
        #expect(NetworkError(statusCode: statusCode) == .unauthorized)
    }

    @Test func tooManyRequestsIsRateLimited() {
        #expect(NetworkError(statusCode: 429) == .rateLimited)
    }

    @Test(arguments: [300, 404, 500, 503])
    func otherStatusIsAServerError(statusCode: Int) {
        #expect(NetworkError(statusCode: statusCode) == .server(statusCode: statusCode))
    }

    @Test func onlyPassingFailuresAreTemporary() {
        #expect(NetworkError.offline.isTemporary)
        #expect(NetworkError.rateLimited.isTemporary)
        #expect(NetworkError.server(statusCode: 500).isTemporary)
        #expect(!NetworkError.unauthorized.isTemporary)
        #expect(!NetworkError.invalidResponse.isTemporary)
    }
}
