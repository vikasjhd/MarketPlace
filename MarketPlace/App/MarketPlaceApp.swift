import SwiftUI

// App entry point. Creates the shared objects and passes them to the views.
@main
struct MarketPlaceApp: App {
    // Id of the background refresh task (also listed in Info.plist).
    static let backgroundSyncID = "com.vikassaini.MarketPlace.sync"

    @State private var repository: ListingRepository
    @State private var networkMonitor: NetworkMonitor
    @State private var syncEngine: SyncEngine

    // Creates the database, network monitor and sync engine once at launch.
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
