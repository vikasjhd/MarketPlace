import BackgroundTasks
import os
import SwiftUI

struct RootView: View {
    @Environment(ListingRepository.self) private var repository
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.scenePhase) private var scenePhase
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ListingsView()
        }
        .safeAreaInset(edge: .bottom) {
            SyncStatusBar()
        }
        .task {
            do {
                try repository.load()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            await syncEngine.sync()
        }
        .onChange(of: networkMonitor.isOnline) { _, isOnline in
            if isOnline {
                Task { await syncEngine.sync() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await syncEngine.sync() }
            } else if phase == .background {
                scheduleBackgroundSync()
            }
        }
        .alert("Could not load listings", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // Only asks iOS for background time when there is something to send.
    private func scheduleBackgroundSync() {
        guard repository.pendingCount > 0 else { return }
        let request = BGAppRefreshTaskRequest(identifier: MarketPlaceApp.backgroundSyncID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.sync.error("Could not schedule background sync: \(error.localizedDescription)")
        }
    }
}
