import Foundation
@testable import MarketPlace

actor FakeListingsAPI: ListingsAPI {
    private(set) var calls: [String] = []
    private var saveError: APIError?
    private var changesResponse = ChangesResponse(listings: [], latestRevision: 0)
    private var nextRevision = 1

    func setSaveError(_ error: APIError?) {
        saveError = error
    }

    func setChanges(_ response: ChangesResponse) {
        changesResponse = response
    }

    func uploadImage(id: UUID, jpeg: Data) async throws -> URL {
        calls.append("upload")
        return URL(string: "https://mock.marketplace.local/images/\(id.uuidString)")!
    }

    func create(_ dto: ListingDTO) async throws -> ListingDTO {
        calls.append("create")
        return try save(dto)
    }

    func update(_ dto: ListingDTO) async throws -> ListingDTO {
        calls.append("update")
        return try save(dto)
    }

    func changes(since revision: Int) async throws -> ChangesResponse {
        calls.append("changes")
        return changesResponse
    }

    private func save(_ dto: ListingDTO) throws -> ListingDTO {
        if let saveError {
            throw saveError
        }
        var saved = dto
        saved.revision = nextRevision
        nextRevision += 1
        return saved
    }
}
