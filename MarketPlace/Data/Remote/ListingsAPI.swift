import Foundation

// What the sync engine needs from a server. A protocol so tests can use a fake.
protocol ListingsAPI: Sendable {
    func uploadImage(id: UUID, jpeg: Data) async throws -> URL
    func create(_ dto: ListingDTO) async throws -> ListingDTO
    func update(_ dto: ListingDTO) async throws -> ListingDTO
    func changes(since revision: Int) async throws -> ChangesResponse
}

// Server and network errors, grouped by what the app should do.
enum APIError: Error, Equatable {
    // No internet, lost connection or timeout.
    case offline
    // Server error (5xx).
    case server(Int)
    // Missing or wrong token (401).
    case unauthorized
    // The server kept its own newer copy and sent it back.
    case conflict(ListingDTO)
    // The server rejected the data (422), with a message.
    case validation(String)
    // Any other HTTP status.
    case unexpectedStatus(Int)
    // The answer could not be read.
    case decoding
}
