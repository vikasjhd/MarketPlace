import Foundation
import Observation
import SwiftData

// Errors the repository can throw.
enum ListingRepositoryError: Error {
    case notFound
    case invalidPrice
}

// The only place that reads and writes listings. Views get plain Listing structs.
@MainActor
@Observable
final class ListingRepository {
    // All listings, newest first. Views update when this changes.
    private(set) var listings: [Listing] = []

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let context: ModelContext

    // Opens the database. Tests pass inMemory: true so nothing is written to disk.
    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: ListingRecord.self, configurations: configuration)
        context = container.mainContext
    }

    // Number of listings waiting to be sent.
    var pendingCount: Int {
        listings.filter { $0.syncState == .pending }.count
    }

    // Number of listings the server rejected.
    var failedCount: Int {
        listings.filter { $0.syncState == .failed }.count
    }

    // Reads all listings from the database into `listings`.
    // Sorted in Swift, not with SortDescriptor: SwiftData key paths aren't Sendable under strict concurrency.
    func load() throws {
        let records = try context.fetch(FetchDescriptor<ListingRecord>())
        listings = try records
            .map { try $0.toListing() }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // Finds one listing in memory.
    func listing(id: UUID) -> Listing? {
        listings.first { $0.id == id }
    }

    // Saves a new listing as pending. It is sent on the next sync.
    func create(_ draft: ListingDraft) throws -> Listing {
        guard let priceCents = ListingValidator.priceCents(from: draft.priceText) else {
            throw ListingRepositoryError.invalidPrice
        }
        let now = Date()
        let listing = Listing(
            id: UUID(),
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: draft.details.trimmingCharacters(in: .whitespacesAndNewlines),
            priceCents: priceCents,
            category: draft.category,
            images: draft.images,
            ownerID: Listing.currentUserID,
            createdAt: now,
            updatedAt: now,
            revision: nil,
            isFavorite: false,
            syncState: .pending,
            syncError: nil
        )
        context.insert(try ListingRecord(listing: listing))
        try saveAndReload()
        return listing
    }

    // Saves the user's edit and marks it pending again.
    func update(id: UUID, with draft: ListingDraft) throws {
        guard let priceCents = ListingValidator.priceCents(from: draft.priceText) else {
            throw ListingRepositoryError.invalidPrice
        }
        let record = try record(id: id)
        record.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines)
        record.priceCents = priceCents
        record.category = draft.category
        try record.setImages(draft.images)
        record.updatedAt = Date()
        // A user edit always goes back in the queue, even if the last push failed.
        record.syncState = .pending
        record.syncError = nil
        try saveAndReload()
    }

    // Turns favorite on or off.
    // Favorites are local only, so this must not touch updatedAt or the sync state.
    func toggleFavorite(id: UUID) throws {
        let record = try record(id: id)
        record.isFavorite.toggle()
        try saveAndReload()
    }

    // Listings waiting to be sent, oldest first.
    func pendingListings() -> [Listing] {
        listings
            .filter { $0.syncState == .pending }
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    // Saves the server URL of one uploaded photo.
    func setRemoteURL(_ url: URL, imageID: UUID, listingID: UUID) throws {
        let record = try record(id: listingID)
        var images = try record.images()
        guard let index = images.firstIndex(where: { $0.id == imageID }) else { return }
        images[index].remoteURL = url
        try record.setImages(images)
        try saveAndReload()
    }

    // Called after the server accepted the listing, or sent back its newer copy.
    func markSynced(id: UUID, pushedUpdatedAt: Date, server: Listing) throws {
        let record = try record(id: id)
        if record.updatedAt == pushedUpdatedAt {
            try copyServerFields(from: server, to: record)
        } else {
            // The user edited during the push. Keep the edit pending, but save the revision so the next push is a PUT.
            record.revision = server.revision
        }
        try saveAndReload()
    }

    // Marks a listing as rejected by the server, with the message to show.
    func markFailed(id: UUID, pushedUpdatedAt: Date, message: String) throws {
        let record = try record(id: id)
        // If the user edited during the push, the new edit gets its own try.
        guard record.updatedAt == pushedUpdatedAt else { return }
        record.syncState = .failed
        record.syncError = message
        try saveAndReload()
    }

    // Saves listings that came from the server, in one batch.
    func applyPulled(_ serverListings: [Listing]) throws {
        let records = try context.fetch(FetchDescriptor<ListingRecord>())
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        for server in serverListings {
            if let record = recordsByID[server.id] {
                // Local changes not yet on the server must not be overwritten.
                if record.syncState == .pending || record.syncState == .failed {
                    continue
                }
                try copyServerFields(from: server, to: record)
            } else {
                var listing = server
                listing.isFavorite = false
                listing.syncState = .synced
                listing.syncError = nil
                context.insert(try ListingRecord(listing: listing))
            }
        }
        try saveAndReload()
    }

    // Finds the database row for an id.
    // Found in Swift, not with #Predicate, for the same Sendable reason as load().
    private func record(id: UUID) throws -> ListingRecord {
        let records = try context.fetch(FetchDescriptor<ListingRecord>())
        guard let record = records.first(where: { $0.id == id }) else {
            throw ListingRepositoryError.notFound
        }
        return record
    }

    // Copies the server's version into the row and marks it synced.
    // Keeps local-only data: the favorite flag and file names of photos taken on this phone.
    private func copyServerFields(from server: Listing, to record: ListingRecord) throws {
        let localImages = try record.images()
        var images = server.images
        for index in images.indices {
            if let local = localImages.first(where: { $0.id == images[index].id }) {
                images[index].localFilename = local.localFilename
            }
        }

        record.title = server.title
        record.details = server.details
        record.priceCents = server.priceCents
        record.category = server.category
        try record.setImages(images)
        record.updatedAt = server.updatedAt
        record.revision = server.revision
        record.syncState = .synced
        record.syncError = nil
    }

    // Saves to disk and refreshes `listings`.
    private func saveAndReload() throws {
        try context.save()
        try load()
    }
}
