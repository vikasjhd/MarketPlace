import SwiftUI

@main
struct MarketPlaceApp: App {
    @State private var repository: ListingRepository

    init() {
        do {
            _repository = State(initialValue: try ListingRepository())
        } catch {
            // Without local storage the app can't work at all.
            fatalError("Could not open the local database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(repository)
        }
    }
}
