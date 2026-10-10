import Foundation

// A protocol so tests can switch "online" on and off.
@MainActor
protocol Connectivity: AnyObject {
    var isOnline: Bool { get }
}
