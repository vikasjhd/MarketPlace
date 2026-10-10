import SwiftUI

// Bar at the bottom that shows the sync state, with Retry after an error.
struct SyncStatusBar: View {
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(ListingRepository.self) private var repository
    @Environment(NetworkMonitor.self) private var networkMonitor

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // Picks the message: offline first, then syncing, error, failed, pending, up to date.
    @ViewBuilder
    private var content: some View {
        let pending = repository.pendingCount
        let failed = repository.failedCount

        if !networkMonitor.isOnline || syncEngine.status == .offline {
            Label(pending > 0 ? "Offline · \(pending) pending" : "Offline", systemImage: "wifi.slash")
        } else if syncEngine.status == .syncing {
            ProgressView()
            Text("Syncing…")
        } else if case .error(let message) = syncEngine.status {
            Label(message, systemImage: "exclamationmark.triangle")
            Button("Retry") {
                Task { await syncEngine.sync() }
            }
        } else if failed > 0 {
            Label("\(failed) failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } else if pending > 0 {
            Label("\(pending) pending", systemImage: "clock")
        } else {
            Label("Up to date", systemImage: "checkmark.circle")
        }
    }
}
