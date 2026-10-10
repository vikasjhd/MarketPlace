import SwiftUI

// Small label on a row: Pending or Failed. Nothing when synced.
struct SyncBadge: View {
    let state: SyncState

    var body: some View {
        switch state {
        case .synced:
            EmptyView()
        case .pending:
            Label("Pending", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.orange)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
