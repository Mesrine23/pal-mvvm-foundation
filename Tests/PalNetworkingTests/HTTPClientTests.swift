import Foundation
import Testing
@testable import PalNetworking

private actor RequestBin {

    private(set) var requests: [TransportRequest] = []

    func record(_ request: TransportRequest) {
        requests.append(request)
    }

    var last: TransportRequest? {
        requests.last
    }
}

private struct CapturingStub: Interceptor {

    let bin: RequestBin
    var response = NetworkResponse(statusCode: 200)

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        await bin.record(request)
        return response
    }
}

private struct SendOnlyClient: NetworkClient {

    func send<Response>(_ request: Request<Response>) async throws(NetworkError) -> Response {
        guard let value = EmptyResponse() as? Response else {
            throw .invalidRequest
        }
        return value
    }
}

@Suite("HTTPClient request building")
struct HTTPClientTests {

    private func makeClient(
        bin: RequestBin,
        response: NetworkResponse = NetworkResponse(statusCode: 200)
    ) throws -> HTTPClient {
        let baseURL = try #require(URL(string: "https://api.example.test"))
        return HTTPClient(baseURL: baseURL, interceptors: [CapturingStub(bin: bin, response: response)])
    }

    @Test("A literal + in a query value is emitted as %2B, not left for servers to read as a space")
    func plusIsPercentEncoded() async throws {
        let bin = RequestBin()
        let client = try makeClient(bin: bin)

        _ = try await client.send(Request<EmptyResponse>(path: "/search", query: [URLQueryItem(name: "q", value: "a+b")]))

        let url = try #require(await bin.last?.urlRequest.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.percentEncodedQuery == "q=a%2Bb")
    }

    @Test("Spaces and unicode still round-trip after the plus fix")
    func standardEncodingUnaffected() async throws {
        let bin = RequestBin()
        let client = try makeClient(bin: bin)

        _ = try await client.send(Request<EmptyResponse>(path: "/search", query: [URLQueryItem(name: "q", value: "café 日本")]))

        let url = try #require(await bin.last?.urlRequest.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first?.value == "café 日本")
        #expect(components.percentEncodedQuery?.contains("+") == false)
    }

    @Test("A per-request timeout lands on the URLRequest")
    func timeoutIsApplied() async throws {
        let bin = RequestBin()
        let client = try makeClient(bin: bin)

        _ = try await client.send(Request<EmptyResponse>(path: "/slow", options: RequestOptions(timeout: .seconds(5))))

        #expect(await bin.last?.urlRequest.timeoutInterval == 5)
    }

    @Test("The KeyValuePairs query initializer preserves literal order")
    func keyValuePairsQueryOrder() async throws {
        let bin = RequestBin()
        let client = try makeClient(bin: bin)

        _ = try await client.send(Request<EmptyResponse>(path: "/posts", query: ["page": "2", "limit": "20"]))

        let url = try #require(await bin.last?.urlRequest.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.percentEncodedQuery == "page=2&limit=20")
    }

    @Test("sendWithResponse surfaces the status code and headers alongside the value")
    func sendWithResponseSurfacesMetadata() async throws {
        let bin = RequestBin()
        let stubbed = NetworkResponse(statusCode: 201, headers: ["X-Test": "yes"])
        let client = try makeClient(bin: bin, response: stubbed)

        let (_, response) = try await client.sendWithResponse(Request<EmptyResponse>(path: "/created"))

        #expect(response.statusCode == 201)
        #expect(response.headers["X-Test"] == "yes")
    }

    @Test("The protocol's default sendWithResponse forwards to send with placeholder metadata")
    func defaultSendWithResponse() async throws {
        let client = SendOnlyClient()

        let (_, response) = try await client.sendWithResponse(Request<EmptyResponse>(path: "/anything"))

        #expect(response.statusCode == 0)
        #expect(response.headers.isEmpty)
    }

    @Test("MultipartPart factories fill name, type, and bytes")
    func multipartFactories() {
        let text = MultipartPart.text(name: "title", value: "Hello")
        #expect(text.name == "title")
        #expect(text.mimeType == "text/plain")
        #expect(text.filename == nil)
        #expect(text.data == Data("Hello".utf8))

        let file = MultipartPart.file(name: "file", filename: "blob.bin", contentType: "application/octet-stream", data: Data([1, 2]))
        #expect(file.filename == "blob.bin")
        #expect(file.mimeType == "application/octet-stream")
        #expect(file.data.count == 2)
    }
}
