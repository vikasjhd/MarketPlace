import Foundation

struct Listing: Identifiable, Equatable, Sendable {
    // The only user in this app; the mock token belongs to this id.
    static let currentUserID = "dev-user"

    let id: UUID
    var title: String
    var details: String
    var priceCents: Int
    var category: Category
    var images: [ListingImage]
    let ownerID: String
    let createdAt: Date
    // Last-write-wins clock, so it changes only on user edits.
    var updatedAt: Date
    // nil means the server has never accepted this listing, so the next push is a POST.
    var revision: Int?
    var isFavorite: Bool
    var syncState: SyncState
    var syncError: String?
}

enum SyncState: String, Codable, Sendable {
    case synced
    case pending
    case failed
}
