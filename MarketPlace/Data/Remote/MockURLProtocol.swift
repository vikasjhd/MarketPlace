import Foundation

// Catches requests to the mock host and answers them from MockServer, so nothing goes over the network.
final class MockURLProtocol: URLProtocol {
    // Only handle requests to the mock host.
    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == MockServer.host
    }

    // Required by URLProtocol. The request is used as is.
    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    // Gets the answer from MockServer and hands it back to URLSession.
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response = MockServer.shared.handle(
            method: request.httpMethod ?? "GET",
            url: url,
            headers: request.allHTTPHeaderFields ?? [:],
            body: requestBody()
        )

        let headers = ["Content-Type": response.contentType]
        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    // Nothing to stop, the answer is sent right away.
    override func stopLoading() {}

    // URLSession often moves httpBody into a stream before it reaches a URLProtocol.
    private func requestBody() -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        stream.open()
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 {
                break
            }
            data.append(buffer, count: count)
        }
        stream.close()
        return data
    }
}

extension URLSession {
    // Like URLSession.shared, but every request goes to the in-app mock server.
    static let mock: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
}
