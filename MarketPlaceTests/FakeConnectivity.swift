@testable import MarketPlace

@MainActor
final class FakeConnectivity: Connectivity {
    var isOnline = true
}
