import SwiftUI

@main
struct MarketPlaceApp: App {
    static let backgroundSyncID = "com.vikassaini.MarketPlace.sync"

    @State private var repository: ListingRepository
    @State private var networkMonitor: NetworkMonitor
    @State private var syncEngine: SyncEngine

    init() {
        let repository: ListingRepository
        do {
            repository = try ListingRepository()
        } catch {
            // Without local storage the app can't work at all.
            fatalError("Could not open the local database: \(error)")
        }
        let networkMonitor = NetworkMonitor()

        _repository = State(initialValue: repository)
        _networkMonitor = State(initialValue: networkMonitor)
        _syncEngine = State(initialValue: SyncEngine(
            repository: repository,
            api: HTTPListingsAPI(),
            connectivity: networkMonitor,
            fileStore: .app,
            defaults: .standard
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(repository)
                .environment(networkMonitor)
                .environment(syncEngine)
        }
        // iOS decides when this runs. Foreground sync is the main path.
        .backgroundTask(.appRefresh(Self.backgroundSyncID)) { [syncEngine] in
            await syncEngine.sync()
        }
    }
}
