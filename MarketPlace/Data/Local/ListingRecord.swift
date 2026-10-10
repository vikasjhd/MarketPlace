import Foundation
import SwiftData

// The database row for a listing (SwiftData). Only the repository uses it.
@Model
final class ListingRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var priceCents: Int
    var category: Category
    // Images are stored as JSON to avoid iOS 17 issues with arrays of Codable structs.
    var imagesData: Data
    var ownerID: String
    var createdAt: Date
    var updatedAt: Date
    var revision: Int?
    var isFavorite: Bool
    var syncState: SyncState
    var syncError: String?

    // Makes a database row from a Listing.
    init(listing: Listing) throws {
        id = listing.id
        title = listing.title
        details = listing.details
        priceCents = listing.priceCents
        category = listing.category
        imagesData = try JSONEncoder().encode(listing.images)
        ownerID = listing.ownerID
        createdAt = listing.createdAt
        updatedAt = listing.updatedAt
        revision = listing.revision
        isFavorite = listing.isFavorite
        syncState = listing.syncState
        syncError = listing.syncError
    }

    // Reads the photo list from its JSON.
    func images() throws -> [ListingImage] {
        try JSONDecoder().decode([ListingImage].self, from: imagesData)
    }

    // Saves the photo list as JSON.
    func setImages(_ images: [ListingImage]) throws {
        imagesData = try JSONEncoder().encode(images)
    }

    // Turns the row into the Listing struct the app uses.
    func toListing() throws -> Listing {
        Listing(
            id: id,
            title: title,
            details: details,
            priceCents: priceCents,
            category: category,
            images: try images(),
            ownerID: ownerID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            isFavorite: isFavorite,
            syncState: syncState,
            syncError: syncError
        )
    }
}
