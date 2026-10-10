import Foundation
import Network
import Observation

// A protocol so tests can switch "online" on and off.
@MainActor
protocol Connectivity: AnyObject {
    var isOnline: Bool { get }
}

@MainActor
@Observable
final class NetworkMonitor: Connectivity {
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            // NWPathMonitor calls back on its own queue; UI state lives on the main actor.
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}
