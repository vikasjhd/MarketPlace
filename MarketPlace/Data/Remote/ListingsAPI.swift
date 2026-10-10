import Foundation

protocol ListingsAPI: Sendable {
    func uploadImage(id: UUID, jpeg: Data) async throws -> URL
    func create(_ dto: ListingDTO) async throws -> ListingDTO
    func update(_ dto: ListingDTO) async throws -> ListingDTO
    func changes(since revision: Int) async throws -> ChangesResponse
}

enum APIError: Error, Equatable {
    case offline
    case server(Int)
    case unauthorized
    // The server kept its own newer copy and sent it back.
    case conflict(ListingDTO)
    case validation(String)
    case unexpectedStatus(Int)
    case decoding
}
