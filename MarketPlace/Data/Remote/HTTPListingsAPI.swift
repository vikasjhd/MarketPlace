import Foundation

// Talks to the server over HTTP. Adds the token and turns status codes into APIError.
final class HTTPListingsAPI: ListingsAPI {
    private let session: URLSession
    private let keychain: KeychainStore

    init(session: URLSession = .mock, keychain: KeychainStore = KeychainStore()) {
        self.session = session
        self.keychain = keychain
    }

    // Uploads one photo as JPEG and returns its server URL.
    func uploadImage(id: UUID, jpeg: Data) async throws -> URL {
        var request = try await authorizedRequest(path: "/images/\(id.uuidString)", method: "PUT")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpeg
        let data = try await send(request)
        return try decode(UploadResponse.self, from: data).url
    }

    // Sends a new listing (POST).
    func create(_ dto: ListingDTO) async throws -> ListingDTO {
        try await sendListing(dto, path: "/listings", method: "POST")
    }

    // Sends an edited listing (PUT).
    func update(_ dto: ListingDTO) async throws -> ListingDTO {
        try await sendListing(dto, path: "/listings/\(dto.id.uuidString)", method: "PUT")
    }

    // Asks for listings changed after the given revision.
    func changes(since revision: Int) async throws -> ChangesResponse {
        let query = [URLQueryItem(name: "sinceRevision", value: String(revision))]
        let request = try await authorizedRequest(path: "/listings", method: "GET", query: query)
        let data = try await send(request)
        return try decode(ChangesResponse.self, from: data)
    }

    // Sends a listing as JSON and reads back the server's copy.
    private func sendListing(_ dto: ListingDTO, path: String, method: String) async throws -> ListingDTO {
        var request = try await authorizedRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.api.encode(dto)
        let data = try await send(request)
        return try decode(ListingDTO.self, from: data)
    }

    // Builds a request with the Bearer token.
    private func authorizedRequest(
        path: String,
        method: String,
        query: [URLQueryItem] = []
    ) async throws -> URLRequest {
        var request = URLRequest(url: try makeURL(path: path, query: query))
        request.httpMethod = method
        request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        return request
    }

    // Uses the saved token, or asks the server for one the first time.
    private func token() async throws -> String {
        if let token = keychain.readToken() {
            return token
        }
        let request = URLRequest(url: try makeURL(path: "/auth/token"))
        let data = try await send(request)
        let token = try decode(TokenResponse.self, from: data).token
        try keychain.saveToken(token)
        return token
    }

    // Runs the request and maps the HTTP status to data or an APIError.
    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapped(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.decoding
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            // The next request will fetch a fresh token.
            keychain.deleteToken()
            throw APIError.unauthorized
        case 409:
            throw APIError.conflict(try decode(ListingDTO.self, from: data))
        case 422:
            let message = (try? decode(ErrorResponse.self, from: data))?.message ?? "The server rejected this listing."
            throw APIError.validation(message)
        case 500...599:
            throw APIError.server(http.statusCode)
        default:
            throw APIError.unexpectedStatus(http.statusCode)
        }
    }

    // Turns network errors into APIError, and cancel into CancellationError.
    private func mapped(_ error: URLError) -> Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut:
            return APIError.offline
        case .cancelled:
            return CancellationError()
        default:
            return error
        }
    }

    // Builds a full URL for the mock host.
    private func makeURL(path: String, query: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = MockServer.host
        components.path = path
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    // Reads JSON, or throws .decoding if it doesn't match.
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.api.decode(type, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
