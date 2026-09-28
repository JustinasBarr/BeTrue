import Combine

extension Publisher where Failure == Never {
    /// Awaits work a view model started in its own `Task`, without sleeping. A `@Published` property
    /// replays its current value, so a condition that already holds returns at once.
    @MainActor
    func firstValue(where predicate: @escaping (Output) -> Bool) async {
        var subscription: AnyCancellable?
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            subscription = first(where: predicate).sink { _ in continuation.resume() }
        }
        subscription?.cancel()
    }
}
