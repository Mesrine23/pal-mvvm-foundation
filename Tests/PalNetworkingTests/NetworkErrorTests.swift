import Foundation
import Testing
@testable import PalNetworking

@Suite("NetworkError")
struct NetworkErrorTests {

    @Test("429 and 5xx are retriable; other 4xx are not")
    func retriability() {
        #expect(NetworkError.unacceptableStatus(code: 429, data: Data(), headers: [:]).isRetriable)
        #expect(NetworkError.unacceptableStatus(code: 503, data: Data(), headers: [:]).isRetriable)
        #expect(!NetworkError.unacceptableStatus(code: 404, data: Data(), headers: [:]).isRetriable)
        #expect(NetworkError.transport(URLError(.timedOut)).isRetriable)
        #expect(!NetworkError.cancelled.isRetriable)
    }

    @Test("The accessors expose the case payloads without pattern matching")
    func accessors() {
        let error = NetworkError.unacceptableStatus(code: 418, data: Data([1]), headers: ["X-A": "1"])
        #expect(error.statusCode == 418)
        #expect(error.responseHeaders?["X-A"] == "1")
        #expect(error.urlError == nil)

        let transport = NetworkError.transport(URLError(.notConnectedToInternet))
        #expect(transport.urlError?.code == .notConnectedToInternet)
        #expect(transport.statusCode == nil)
    }

    @Test("Retry-After parses integer seconds, case-insensitively, tolerating whitespace")
    func retryAfterParsing() {
        func error(_ headers: [String: String]) -> NetworkError {
            .unacceptableStatus(code: 429, data: Data(), headers: headers)
        }
        #expect(error(["Retry-After": "2"]).retryAfter == .seconds(2))
        #expect(error(["retry-after": " 3 "]).retryAfter == .seconds(3))
        #expect(error([:]).retryAfter == nil)
        #expect(error(["Retry-After": "soon"]).retryAfter == nil)
        #expect(error(["Retry-After": "-1"]).retryAfter == nil)
        #expect(NetworkError.cancelled.retryAfter == nil)
    }

    @Test("The description never leaks header values or bodies into logs")
    func redactedDescription() {
        let error = NetworkError.unacceptableStatus(
            code: 401,
            data: Data("token=top-secret".utf8),
            headers: ["Set-Cookie": "session=top-secret"]
        )
        let text = String(describing: error)
        #expect(text.contains("401"))
        #expect(!text.contains("top-secret"))
        #expect(!text.contains("Set-Cookie"))
    }
}
