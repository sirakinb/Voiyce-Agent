import Foundation
import Network

@Observable
final class NetworkMonitor {
    var isConnected: Bool

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "voiyce.network.monitor")

    init() {
        isConnected = !AppConstants.uiTestingForcesOffline

        guard !AppConstants.uiTestingForcesOffline else {
            return
        }

        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
