import Foundation
@testable import BeTrue

final class InMemoryLocalStore: LocalStoring, @unchecked Sendable {
    var saveCount: Int {
        lock.withLock { recordedSaveCount }
    }

    private let lock = NSLock()
    private var values: [String: SavedData] = [:]
    private var recordedSaveCount = 0
    private let now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    func savedData(forKey key: String) async -> SavedData? {
        lock.withLock { values[key] }
    }

    func save(_ data: Data, forKey key: String) async {
        lock.withLock {
            values[key] = SavedData(data: data, savedAt: now)
            recordedSaveCount += 1
        }
    }

    /// Every value shares one save time here, so which of the matching values stay is unspecified.
    func removeSavedData(withKeyPrefix prefix: String, keepingNewest count: Int) async {
        lock.withLock {
            let stale = values.keys.filter { $0.hasPrefix(prefix) }.sorted().dropFirst(count)
            stale.forEach { values[$0] = nil }
        }
    }
}
