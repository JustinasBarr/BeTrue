import Foundation
import Testing
@testable import BeTrue

/// After `holdResponses()`, calls wait until the test resumes them, so a test can finish requests in any
/// order to reproduce races.
final class FakePhotoRepository: PhotoRepository, @unchecked Sendable {
    enum Call: Hashable, Sendable {
        case curated(page: Int)
        case search(query: String, page: Int)
    }

    var calls: [Call] {
        lock.withLock { recordedCalls }
    }

    private let lock = NSLock()
    private var recordedCalls: [Call] = []
    private var responder: @Sendable (Call) throws -> PhotoPage
    private var holdsResponses = false
    private var heldCalls: [HeldCall] = []
    private var callWaiters: [CallWaiter] = []

    private struct HeldCall {
        let call: Call
        let continuation: CheckedContinuation<PhotoPage, any Error>
    }

    private struct CallWaiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    init(responder: @escaping @Sendable (Call) throws -> PhotoPage = { _ in throw NetworkError.offline }) {
        self.responder = responder
    }

    func respond(with responder: @escaping @Sendable (Call) throws -> PhotoPage) {
        lock.withLock { self.responder = responder }
    }

    func respond(with page: PhotoPage) {
        respond { _ in page }
    }

    func fail(with error: any Error) {
        respond { _ in throw error }
    }

    func holdResponses() {
        lock.withLock { holdsResponses = true }
    }

    func waitForCalls(_ count: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let isReady = lock.withLock {
                guard recordedCalls.count < count else { return true }
                callWaiters.append(CallWaiter(count: count, continuation: continuation))
                return false
            }
            if isReady { continuation.resume() }
        }
    }

    func resume(_ call: Call, returning page: PhotoPage) {
        takeHeldCall(call)?.resume(returning: page)
    }

    func resume(_ call: Call, throwing error: any Error) {
        takeHeldCall(call)?.resume(throwing: error)
    }

    func curatedPhotos(page: Int) async throws -> PhotoPage {
        try await answer(.curated(page: page))
    }

    func searchPhotos(matching query: String, filters: SearchFilters, page: Int) async throws -> PhotoPage {
        try await answer(.search(query: query, page: page))
    }

    private func answer(_ call: Call) async throws -> PhotoPage {
        let (isHeld, responder) = lock.withLock { (holdsResponses, self.responder) }
        guard isHeld else {
            record(call, heldBy: nil)
            return try responder(call)
        }
        return try await withCheckedThrowingContinuation { continuation in
            record(call, heldBy: continuation)
        }
    }

    /// Records the call and wakes waiters in one step, so a woken test always finds a held call resumable.
    private func record(_ call: Call, heldBy continuation: CheckedContinuation<PhotoPage, any Error>?) {
        let ready: [CallWaiter] = lock.withLock {
            recordedCalls.append(call)
            if let continuation { heldCalls.append(HeldCall(call: call, continuation: continuation)) }
            let ready = callWaiters.filter { $0.count <= recordedCalls.count }
            callWaiters.removeAll { $0.count <= recordedCalls.count }
            return ready
        }
        ready.forEach { $0.continuation.resume() }
    }

    private func takeHeldCall(_ call: Call) -> CheckedContinuation<PhotoPage, any Error>? {
        let continuation: CheckedContinuation<PhotoPage, any Error>? = lock.withLock {
            guard let index = heldCalls.firstIndex(where: { $0.call == call }) else { return nil }
            return heldCalls.remove(at: index).continuation
        }
        if continuation == nil {
            Issue.record("No held call \(call)")
        }
        return continuation
    }
}
