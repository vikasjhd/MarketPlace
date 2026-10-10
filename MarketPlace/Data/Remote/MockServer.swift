import Foundation
import os
import UIKit

// A fake backend that runs inside the app. MockURLProtocol sends every request here.
final class MockServer: Sendable {
    // Host name the app sends requests to.
    static let host = "mock.marketplace.local"
    // The one server the app uses.
    static let shared = MockServer(folder: URL.applicationSupportDirectory.appending(path: "MockServer"))

    // What the server answers: status code, body and content type.
    struct Response {
        let status: Int
        let body: Data
        let contentType: String
    }

    // Everything the server keeps. Saved as JSON.
    private struct State: Codable {
        var listings: [ListingDTO]
        var latestRevision: Int
        var token: String
    }

    private let folder: URL
    private let state: OSAllocatedUnfairLock<State>

    // Loads saved state, or creates 200 sample listings on first start.
    init(folder: URL) {
        self.folder = folder
        let stateFile = folder.appending(path: "state.json")
        if let data = try? Data(contentsOf: stateFile),
           let saved = try? JSONDecoder.api.decode(State.self, from: data) {
            state = OSAllocatedUnfairLock(initialState: saved)
        } else {
            let listings = Self.seedListings()
            state = OSAllocatedUnfairLock(initialState: State(
                listings: listings,
                latestRevision: listings.count,
                token: UUID().uuidString
            ))
            state.withLock { save($0) }
        }
    }

    // Entry point for every request: picks the endpoint from the method and path.
    func handle(method: String, url: URL, headers: [String: String], body: Data) -> Response {
        let parts = Array(url.pathComponents.dropFirst())
        let isImageDownload = method == "GET" && parts.first == "images"
        if !isImageDownload {
            // Slow enough to see "Syncing…" in the app.
            Thread.sleep(forTimeInterval: 0.3)
        }

        if method == "GET" && parts == ["auth", "token"] {
            return tokenResponse()
        }
        if isImageDownload && parts.count == 2, let id = UUID(uuidString: parts[1]) {
            return imageResponse(id: id)
        }
        guard isAuthorized(headers) else {
            return errorResponse(status: 401, message: "Missing or wrong token.")
        }

        switch (method, parts.count) {
        case ("GET", 1) where parts[0] == "listings":
            return changesResponse(url: url)
        case ("POST", 1) where parts[0] == "listings":
            return saveListing(body: body)
        case ("PUT", 2) where parts[0] == "listings":
            return saveListing(body: body)
        case ("PUT", 2) where parts[0] == "images":
            return uploadImage(idText: parts[1], body: body)
        default:
            return errorResponse(status: 404, message: "Not found.")
        }
    }

    // GET /auth/token: gives out the dev token.
    private func tokenResponse() -> Response {
        let token = state.withLock { $0.token }
        return jsonResponse(status: 200, TokenResponse(token: token, userID: Listing.currentUserID))
    }

    // GET /listings: listings with a revision newer than sinceRevision.
    private func changesResponse(url: URL) -> Response {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        let since = Int(query?.first { $0.name == "sinceRevision" }?.value ?? "") ?? 0

        let response = state.withLock { state in
            let changed = state.listings
                .filter { ($0.revision ?? 0) > since }
                .sorted { ($0.revision ?? 0) < ($1.revision ?? 0) }
            return ChangesResponse(listings: changed, latestRevision: state.latestRevision)
        }
        return jsonResponse(status: 200, response)
    }

    // POST and PUT /listings: validates, applies last write wins, saves.
    // Used for both POST and PUT, so a retried POST can't create a duplicate.
    private func saveListing(body: Data) -> Response {
        guard let incoming = try? JSONDecoder.api.decode(ListingDTO.self, from: body) else {
            return errorResponse(status: 400, message: "Bad listing data.")
        }
        if let message = validationMessage(for: incoming) {
            return errorResponse(status: 422, message: message)
        }

        return state.withLock { state in
            let index = state.listings.firstIndex { $0.id == incoming.id }
            // Last write wins: an older edit loses and gets the newer copy back.
            if let index, incoming.updatedAt < state.listings[index].updatedAt {
                return jsonResponse(status: 409, state.listings[index])
            }

            var saved = incoming
            state.latestRevision += 1
            saved.revision = state.latestRevision
            if let index {
                state.listings[index] = saved
            } else {
                state.listings.append(saved)
            }
            save(state)
            return jsonResponse(status: 200, saved)
        }
    }

    // PUT /images/{id}: saves the photo file and returns its URL.
    private func uploadImage(idText: String, body: Data) -> Response {
        guard let id = UUID(uuidString: idText), !body.isEmpty else {
            return errorResponse(status: 400, message: "Bad image.")
        }
        do {
            try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
            try body.write(to: imageFile(id: id), options: .atomic)
        } catch {
            return errorResponse(status: 500, message: "Could not save the image.")
        }
        return jsonResponse(status: 200, UploadResponse(url: Self.imageURL(id: id)))
    }

    // GET /images/{id}: returns an uploaded photo, or draws one for sample listings.
    private func imageResponse(id: UUID) -> Response {
        if let data = try? Data(contentsOf: imageFile(id: id)) {
            return Response(status: 200, body: data, contentType: "image/jpeg")
        }
        // Seeded listings have no real photos, so draw a simple one.
        let category = state.withLock { state in
            state.listings.first { listing in listing.images.contains { $0.id == id } }?.category
        }
        guard let category, let data = Self.drawImage(id: id, category: category) else {
            return errorResponse(status: 404, message: "Image not found.")
        }
        return Response(status: 200, body: data, contentType: "image/jpeg")
    }

    // The URL where a photo can be downloaded.
    static func imageURL(id: UUID) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/images/\(id.uuidString)"
        return components.url ?? URL(fileURLWithPath: "/")
    }

    // Folder for uploaded photo files.
    private var imagesFolder: URL {
        folder.appending(path: "images")
    }

    // File path of one uploaded photo.
    private func imageFile(id: UUID) -> URL {
        imagesFolder.appending(path: "\(id.uuidString).jpg")
    }

    // True when the request has the right Bearer token.
    private func isAuthorized(_ headers: [String: String]) -> Bool {
        let token = state.withLock { $0.token }
        return headers["Authorization"] == "Bearer \(token)"
    }

    // Same rules as the app's validator, because a server must not trust the client.
    private func validationMessage(for listing: ListingDTO) -> String? {
        let title = listing.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty || title.count > ListingValidator.titleMaxLength {
            return "Title must be 1 to \(ListingValidator.titleMaxLength) characters."
        }
        if listing.priceCents < 0 || listing.priceCents > ListingValidator.maxPriceCents {
            return "Price is out of range."
        }
        return nil
    }

    // Saved after every change, so the server keeps its data and revisions across app launches.
    private func save(_ state: State) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder.api.encode(state) {
            try? data.write(to: folder.appending(path: "state.json"), options: .atomic)
        }
    }

    // Builds a JSON answer.
    private func jsonResponse<T: Encodable>(status: Int, _ value: T) -> Response {
        let body = (try? JSONEncoder.api.encode(value)) ?? Data()
        return Response(status: status, body: body, contentType: "application/json")
    }

    // Builds an error answer with a message.
    private func errorResponse(status: Int, message: String) -> Response {
        jsonResponse(status: status, ErrorResponse(message: message))
    }
}

extension MockServer {
    // 200 listings from 20 other sellers, so the list has real data to scroll.
    private static func seedListings() -> [ListingDTO] {
        let names: [Category: [String]] = [
            .electronics: ["Bluetooth speaker", "Old laptop", "Headphones", "Smart watch", "Phone charger"],
            .furniture: ["Study table", "Wooden chair", "Bookshelf", "Sofa set", "Bedside table"],
            .clothing: ["Denim jacket", "Cotton kurta", "Running shoes", "Winter coat", "Silk saree"],
            .sports: ["Cricket bat", "Football", "Yoga mat", "Badminton racket", "Cycle helmet"],
            .books: ["Novel set", "School textbooks", "Cook book", "Comics bundle", "Exam guide"],
            .other: ["Plant pot", "Wall clock", "Guitar", "Board game", "Water bottle"]
        ]
        let categories = Category.allCases
        let now = Date()

        return (1...200).map { number in
            let category = categories[number % categories.count]
            let categoryNames = names[category] ?? ["Item"]
            let images = (0...(number % 3)).map { _ in
                let id = UUID()
                return ImageDTO(id: id, url: imageURL(id: id))
            }
            let date = now.addingTimeInterval(Double(-number) * 3600)
            return ListingDTO(
                id: UUID(),
                title: categoryNames[(number / categories.count) % categoryNames.count],
                details: "Good condition. Pickup only.",
                priceCents: (number * 137 % 5000 + 100) * 100,
                category: category,
                images: images,
                ownerID: "seller-\(number % 20 + 1)",
                createdAt: date,
                updatedAt: date,
                revision: number
            )
        }
    }

    // A plain colored square with the category name. The color comes from the id, so it stays the same every time.
    private static func drawImage(id: UUID, category: Category) -> Data? {
        let size = CGSize(width: 600, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let image = renderer.image { context in
            let hue = CGFloat(id.uuid.0) / 255
            UIColor(hue: hue, saturation: 0.5, brightness: 0.85, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let text = category.displayName as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 64),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2)
            text.draw(at: origin, withAttributes: attributes)
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
