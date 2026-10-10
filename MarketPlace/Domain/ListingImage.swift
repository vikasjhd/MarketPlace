import Foundation

struct ListingImage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var localFilename: String?
    var remoteURL: URL?
}
