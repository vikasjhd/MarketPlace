import Foundation

// One photo of a listing. It has a local file, a server URL, or both.
struct ListingImage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    // File name in the app's photo folder, for photos added on this phone.
    var localFilename: String?
    // Server address of the photo after upload.
    var remoteURL: URL?
}
