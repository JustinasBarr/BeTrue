#if DEBUG
import Foundation

/// Fails every request as if the device had no connection, when the app is launched with `-SimulateOffline YES`.
///
/// The simulator cannot turn its network off, so this is how offline behavior is checked there. AVPlayer does not
/// load through URLSession, so videos still play.
nonisolated final class SimulatedOffline: URLProtocol {
    private static let launchArgument = "SimulateOffline"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: launchArgument) }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

extension URLSessionConfiguration {
    /// Makes every request of the session fail when the app is launched with `-SimulateOffline YES`.
    nonisolated func simulateOfflineIfRequested() {
        guard SimulatedOffline.isEnabled else { return }
        protocolClasses = [SimulatedOffline.self]
    }
}
#endif
