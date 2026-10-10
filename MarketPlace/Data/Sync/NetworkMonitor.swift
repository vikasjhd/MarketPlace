import Foundation
import Network
import Observation

// A protocol so tests can switch "online" on and off.
@MainActor
protocol Connectivity: AnyObject {
    var isOnline: Bool { get }
}

// Tells the app if the device is online, using NWPathMonitor.
@MainActor
@Observable
final class NetworkMonitor: Connectivity {
    // True when there is a network connection.
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    // Starts listening for network changes.
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
