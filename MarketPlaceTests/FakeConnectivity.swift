@testable import MarketPlace

// Fake network status that tests can switch on and off.
@MainActor
final class FakeConnectivity: Connectivity {
    var isOnline = true
}
