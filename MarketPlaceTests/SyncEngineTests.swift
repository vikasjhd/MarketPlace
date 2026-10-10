import XCTest
@testable import MarketPlace

@MainActor
final class SyncEngineTests: XCTestCase {
    private var repository: ListingRepository!
    private var api: FakeListingsAPI!
    private var connectivity: FakeConnectivity!
    private var engine: SyncEngine!
    private var tempFolder: URL!
    private var defaultsName: String!

    override func setUp() async throws {
        repository = try ListingRepository(inMemory: true)
        api = FakeListingsAPI()
        connectivity = FakeConnectivity()
        tempFolder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defaultsName = UUID().uuidString

        engine = SyncEngine(
            repository: repository,
            api: api,
            connectivity: connectivity,
            fileStore: ImageFileStore(folder: tempFolder),
            defaults: UserDefaults(suiteName: defaultsName)!
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFolder)
        UserDefaults().removePersistentDomain(forName: defaultsName)
    }

    func test_offline_keepsListingPending_andMakesNoCalls() async throws {
        connectivity.isOnline = false
        let listing = try repository.create(makeDraft())

        await engine.sync()

        XCTAssertEqual(engine.status, .offline)
        XCTAssertEqual(repository.listing(id: listing.id)?.syncState, .pending)
        let calls = await api.calls
        XCTAssertEqual(calls, [])
    }

    func test_newListing_isPosted_andMarkedSynced() async throws {
        let listing = try repository.create(makeDraft())

        await engine.sync()

        let calls = await api.calls
        XCTAssertEqual(calls, ["create", "changes"])
        let saved = repository.listing(id: listing.id)
        XCTAssertEqual(saved?.syncState, .synced)
        XCTAssertEqual(saved?.revision, 1)
        XCTAssertEqual(engine.status, .idle)
    }

    func test_serverError_keepsPending_notFailed() async throws {
        await api.setSaveError(.server(500))
        let listing = try repository.create(makeDraft())

        await engine.sync()

        XCTAssertEqual(repository.listing(id: listing.id)?.syncState, .pending)
        XCTAssertEqual(engine.status, .error("Couldn't reach the server."))
    }

    func test_conflict_appliesServerVersion() async throws {
        let listing = try repository.create(makeDraft())
        var serverCopy = ListingDTO(listing: listing)
        serverCopy.title = "Edited on another phone"
        serverCopy.updatedAt = listing.updatedAt.addingTimeInterval(60)
        serverCopy.revision = 7
        await api.setSaveError(.conflict(serverCopy))

        await engine.sync()

        let saved = repository.listing(id: listing.id)
        XCTAssertEqual(saved?.title, "Edited on another phone")
        XCTAssertEqual(saved?.revision, 7)
        XCTAssertEqual(saved?.syncState, .synced)
    }

    func test_pull_doesNotOverwritePendingListing() async throws {
        let listing = try repository.create(makeDraft())
        var serverCopy = ListingDTO(listing: listing).toListing()
        serverCopy.title = "Old server title"
        serverCopy.revision = 5

        try repository.applyPulled([serverCopy])

        let saved = repository.listing(id: listing.id)
        XCTAssertEqual(saved?.title, "Chair")
        XCTAssertEqual(saved?.syncState, .pending)
    }

    private func makeDraft() -> ListingDraft {
        ListingDraft(title: "Chair", details: "", priceText: "500", category: .furniture, images: [])
    }
}
