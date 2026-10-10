import Foundation
import SwiftData

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

    func images() throws -> [ListingImage] {
        try JSONDecoder().decode([ListingImage].self, from: imagesData)
    }

    func setImages(_ images: [ListingImage]) throws {
        imagesData = try JSONEncoder().encode(images)
    }

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
