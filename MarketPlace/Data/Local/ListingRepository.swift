import Foundation
import Observation
import SwiftData

enum ListingRepositoryError: Error {
    case notFound
    case invalidPrice
}

@MainActor
@Observable
final class ListingRepository {
    private(set) var listings: [Listing] = []

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let context: ModelContext

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: ListingRecord.self, configurations: configuration)
        context = container.mainContext
    }

    var pendingCount: Int {
        listings.filter { $0.syncState == .pending }.count
    }

    var failedCount: Int {
        listings.filter { $0.syncState == .failed }.count
    }

    // Sorted in Swift, not with SortDescriptor: SwiftData key paths aren't Sendable under strict concurrency.
    func load() throws {
        let records = try context.fetch(FetchDescriptor<ListingRecord>())
        listings = try records
            .map { try $0.toListing() }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func listing(id: UUID) -> Listing? {
        listings.first { $0.id == id }
    }

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

    // Favorites are local only, so this must not touch updatedAt or the sync state.
    func toggleFavorite(id: UUID) throws {
        let record = try record(id: id)
        record.isFavorite.toggle()
        try saveAndReload()
    }

    func pendingListings() -> [Listing] {
        listings
            .filter { $0.syncState == .pending }
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    func setRemoteURL(_ url: URL, imageID: UUID, listingID: UUID) throws {
        let record = try record(id: listingID)
        var images = try record.images()
        guard let index = images.firstIndex(where: { $0.id == imageID }) else { return }
        images[index].remoteURL = url
        try record.setImages(images)
        try saveAndReload()
    }

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

    func markFailed(id: UUID, pushedUpdatedAt: Date, message: String) throws {
        let record = try record(id: id)
        // If the user edited during the push, the new edit gets its own try.
        guard record.updatedAt == pushedUpdatedAt else { return }
        record.syncState = .failed
        record.syncError = message
        try saveAndReload()
    }

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

    // Found in Swift, not with #Predicate, for the same Sendable reason as load().
    private func record(id: UUID) throws -> ListingRecord {
        let records = try context.fetch(FetchDescriptor<ListingRecord>())
        guard let record = records.first(where: { $0.id == id }) else {
            throw ListingRepositoryError.notFound
        }
        return record
    }

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

    private func saveAndReload() throws {
        try context.save()
        try load()
    }
}
