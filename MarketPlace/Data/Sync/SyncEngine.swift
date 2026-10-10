import Foundation
import Observation

@MainActor
@Observable
final class SyncEngine {
    enum Status: Equatable {
        case idle
        case syncing
        case offline
        case error(String)
    }

    private(set) var status: Status = .idle

    @ObservationIgnored private let repository: ListingRepository
    @ObservationIgnored private let api: any ListingsAPI
    @ObservationIgnored private let connectivity: any Connectivity
    @ObservationIgnored private let fileStore: ImageFileStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var runAgain = false

    private static let cursorKey = "lastPulledRevision"

    init(
        repository: ListingRepository,
        api: any ListingsAPI,
        connectivity: any Connectivity,
        fileStore: ImageFileStore,
        defaults: UserDefaults
    ) {
        self.repository = repository
        self.api = api
        self.connectivity = connectivity
        self.fileStore = fileStore
        self.defaults = defaults
    }

    func sync() async {
        // If a sync is already running, ask it for one more round instead of starting a second one.
        if isRunning {
            runAgain = true
            return
        }
        isRunning = true
        repeat {
            runAgain = false
            await runOnce()
        } while runAgain
        isRunning = false
    }

    private func runOnce() async {
        guard connectivity.isOnline else {
            status = .offline
            return
        }

        status = .syncing
        do {
            for listing in repository.pendingListings() {
                try await push(listing)
            }
            try await pull()
            status = .idle
        } catch is CancellationError {
            status = .idle
        } catch {
            // Offline, server errors and bad responses: listings stay pending and are retried next time.
            status = .error("Couldn't reach the server.")
        }
    }

    // Uploads photos first, so the listing is sent with their URLs.
    private func push(_ listing: Listing) async throws {
        var listing = listing
        for index in listing.images.indices where listing.images[index].remoteURL == nil {
            let image = listing.images[index]
            guard let filename = image.localFilename, let data = try? await fileStore.read(filename) else {
                try repository.markFailed(
                    id: listing.id,
                    pushedUpdatedAt: listing.updatedAt,
                    message: "A photo is missing. Edit the listing to fix it."
                )
                return
            }
            let url = try await api.uploadImage(id: image.id, jpeg: data)
            try repository.setRemoteURL(url, imageID: image.id, listingID: listing.id)
            listing.images[index].remoteURL = url
        }

        let dto = ListingDTO(listing: listing)
        do {
            let saved = listing.revision == nil ? try await api.create(dto) : try await api.update(dto)
            try repository.markSynced(id: listing.id, pushedUpdatedAt: listing.updatedAt, server: saved.toListing())
        } catch APIError.conflict(let serverCopy) {
            // Last write wins: the server's copy is newer, so it replaces ours.
            try repository.markSynced(
                id: listing.id,
                pushedUpdatedAt: listing.updatedAt,
                server: serverCopy.toListing()
            )
        } catch APIError.validation(let message) {
            try repository.markFailed(id: listing.id, pushedUpdatedAt: listing.updatedAt, message: message)
        } catch APIError.unexpectedStatus(let code) {
            try repository.markFailed(
                id: listing.id,
                pushedUpdatedAt: listing.updatedAt,
                message: "The server rejected this listing (\(code))."
            )
        }
    }

    private func pull() async throws {
        let since = defaults.integer(forKey: Self.cursorKey)
        let response = try await api.changes(since: since)
        try repository.applyPulled(response.listings.map { $0.toListing() })
        // Only moves after the changes are saved, so nothing is skipped if saving fails.
        defaults.set(response.latestRevision, forKey: Self.cursorKey)
    }
}
