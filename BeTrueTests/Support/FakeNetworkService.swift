import Foundation
@testable import BeTrue

// A class with a lock rather than an actor: the compiler rejects actors conforming to the app's
// `nonisolated` protocols when it emits the test module.
final class FakeNetworkService: NetworkService, @unchecked Sendable {
    var requests: [NetworkRequest] {
        lock.withLock { recordedRequests }
    }

    private let lock = NSLock()
    private var recordedRequests: [NetworkRequest] = []
    private var result: Result<Data, any Error>

    init(result: Result<Data, any Error> = .failure(NetworkError.offline)) {
        self.result = result
    }

    func respond(with result: Result<Data, any Error>) {
        lock.withLock { self.result = result }
    }

    func data(for request: NetworkRequest) async throws -> Data {
        try lock.withLock {
            recordedRequests.append(request)
            return try result.get()
        }
    }
}
