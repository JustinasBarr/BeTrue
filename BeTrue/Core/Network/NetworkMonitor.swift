import Combine
import Network

final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()

    init() {
        #if DEBUG
        if SimulatedOffline.isEnabled {
            isOnline = false
            return
        }
        #endif
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.isOnline != isOnline else { return }
                self.isOnline = isOnline
            }
        }
        monitor.start(queue: DispatchQueue(label: String(describing: Self.self)))
    }

    deinit {
        monitor.cancel()
    }
}
