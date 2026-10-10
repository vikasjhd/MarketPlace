import Foundation

// The listing as JSON, the way the server sends and receives it.
struct ListingDTO: Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var details: String
    var priceCents: Int
    var category: Category
    var images: [ImageDTO]
    var ownerID: String
    var createdAt: Date
    var updatedAt: Date
    // nil only when the client sends a new listing.
    var revision: Int?
}

// One photo in the server's JSON: its id and URL.
struct ImageDTO: Codable, Equatable, Sendable {
    let id: UUID
    let url: URL
}

// Answer to a pull: changed listings and the newest revision number.
struct ChangesResponse: Codable, Sendable {
    let listings: [ListingDTO]
    let latestRevision: Int
}

// Answer from /auth/token.
struct TokenResponse: Codable, Sendable {
    let token: String
    let userID: String
}

// Answer after a photo upload: where the photo now lives.
struct UploadResponse: Codable, Sendable {
    let url: URL
}

// Error body the server sends with 4xx answers.
struct ErrorResponse: Codable, Sendable {
    let message: String
}

extension ListingDTO {
    // Favorites and sync state are local only, so they are not sent.
    init(listing: Listing) {
        id = listing.id
        title = listing.title
        details = listing.details
        priceCents = listing.priceCents
        category = listing.category
        images = listing.images.compactMap { image in
            image.remoteURL.map { ImageDTO(id: image.id, url: $0) }
        }
        ownerID = listing.ownerID
        createdAt = listing.createdAt
        updatedAt = listing.updatedAt
        revision = listing.revision
    }

    // Turns server JSON into a Listing marked as synced.
    func toListing() -> Listing {
        Listing(
            id: id,
            title: title,
            details: details,
            priceCents: priceCents,
            category: category,
            images: images.map { ListingImage(id: $0.id, localFilename: nil, remoteURL: $0.url) },
            ownerID: ownerID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            isFavorite: false,
            syncState: .synced,
            syncError: nil
        )
    }
}

// Shared by the app and the mock server so both use the same date format.
extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
