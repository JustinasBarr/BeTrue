import SwiftUI

extension EnvironmentValues {
    /// Set once at the root by `dependencies(_:)`.
    var localStore: any LocalStoring {
        get { self[LocalStoreKey.self] }
        set { self[LocalStoreKey.self] = newValue }
    }
}

private struct LocalStoreKey: EnvironmentKey {
    static let defaultValue: any LocalStoring = MissingLocalStore()
}

/// Stops a debug build when a screen is shown without the real store.
nonisolated private struct MissingLocalStore: LocalStoring {
    func savedData(forKey key: String) async -> SavedData? {
        assertionFailure("localStore is not set in the environment")
        return nil
    }

    func save(_ data: Data, forKey key: String) async {
        assertionFailure("localStore is not set in the environment")
    }

    func removeSavedData(withKeyPrefix prefix: String, keepingNewest count: Int) async {
        assertionFailure("localStore is not set in the environment")
    }
}
