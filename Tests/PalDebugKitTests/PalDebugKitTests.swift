import Foundation
import Testing
import PalNetworking
import PalPersistence
@testable import PalDebugKit

// MARK: - NetworkLogStore

@Test func ringBufferEvictsOldestBeyondCap() async {
    let store = NetworkLogStore(cap: 3)
    for index in 0..<5 {
        await store.record(entry(url: "/\(index)"))
    }
    let all = await store.all
    #expect(all.count == 3)
    #expect(all.first?.url == "/2")
    #expect(all.last?.url == "/4")
}

@Test func clearEmptiesTheBuffer() async {
    let store = NetworkLogStore()
    await store.record(entry(url: "/x"))
    await store.clear()
    #expect(await store.all.isEmpty)
}

// MARK: - DebugInspectorInterceptor

@Test func inspectorRecordsAnEntryWithDuration() async throws {
    let store = NetworkLogStore()
    let interceptor = DebugInspectorInterceptor(store: store)
    let next: Next = { _ in
        try? await Task.sleep(for: .milliseconds(5))
        return NetworkResponse(statusCode: 200, headers: [:], data: Data("{}".utf8))
    }
    _ = try await interceptor.intercept(try transportRequest(method: "GET", url: "https://example.com/users"), next: next)
    let recorded = try #require(await store.all.first)
    #expect(recorded.statusCode == 200)
    #expect(recorded.duration > .zero)
}

@Test func inspectorRedactsSensitiveHeaders() async throws {
    let store = NetworkLogStore()
    let interceptor = DebugInspectorInterceptor(store: store)
    var urlRequest = URLRequest(url: try #require(URL(string: "https://example.com/x")))
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
    let next: Next = { _ in NetworkResponse(statusCode: 200) }
    _ = try await interceptor.intercept(TransportRequest(urlRequest: urlRequest, options: RequestOptions()), next: next)
    let recorded = try #require(await store.all.first)
    #expect(recorded.requestHeaders["Authorization"] == "<redacted>")
}

// MARK: - MockInterceptor / MockRegistry

@Test func mockReturnsStubFor2xxAndSkipsNext() async throws {
    let registry = try makeRegistry()
    await registry.setGlobalEnabled(true)
    let body = Data(#"[{"id":1}]"#.utf8)
    await registry.upsert(MockRecord(method: "GET", path: "/users", isEnabled: true, statusCode: 200, body: body))
    let interceptor = MockInterceptor(registry: registry)
    let next: Next = { _ in
        Issue.record("next must not be called for a matched mock")
        return NetworkResponse(statusCode: 0)
    }
    let response = try await interceptor.intercept(try transportRequest(method: "GET", url: "https://api.example.com/users?page=1"), next: next)
    #expect(response.statusCode == 200)
    #expect(response.data == body)
}

@Test func mockThrowsUnacceptableStatusForNon2xx() async throws {
    let registry = try makeRegistry()
    await registry.setGlobalEnabled(true)
    await registry.upsert(MockRecord(method: "GET", path: "/users", isEnabled: true, statusCode: 500, body: Data("boom".utf8)))
    let interceptor = MockInterceptor(registry: registry)
    let request = try transportRequest(method: "GET", url: "https://api.example.com/users")
    let next: Next = { _ in NetworkResponse(statusCode: 0) }
    do {
        _ = try await interceptor.intercept(request, next: next)
        Issue.record("expected a thrown NetworkError")
    } catch {
        guard case .unacceptableStatus(let code, _, _) = error else {
            Issue.record("expected .unacceptableStatus, got \(error)")
            return
        }
        #expect(code == 500)
    }
}

@Test func disablingGlobalMockingUnmocksEveryRecord() async throws {
    let registry = try makeRegistry()
    await registry.setGlobalEnabled(true)
    await registry.upsert(MockRecord(method: "GET", path: "/users", isEnabled: true, statusCode: 200, body: Data()))
    await registry.upsert(MockRecord(method: "POST", path: "/orders", isEnabled: true, statusCode: 201, body: Data()))

    await registry.setGlobalEnabled(false)

    #expect(await registry.all.allSatisfy { !$0.isEnabled })
    #expect(await registry.enabledKeys().isEmpty)
}

@Test func mockIsBypassedWhenGloballyDisabled() async throws {
    let registry = try makeRegistry()
    await registry.setGlobalEnabled(false)
    await registry.upsert(MockRecord(method: "GET", path: "/users", isEnabled: true, statusCode: 200, body: Data()))
    let interceptor = MockInterceptor(registry: registry)
    let next: Next = { _ in NetworkResponse(statusCode: 204) }
    let response = try await interceptor.intercept(try transportRequest(method: "GET", url: "https://api.example.com/users"), next: next)
    #expect(response.statusCode == 204)
}

// MARK: - EnvironmentStore / EnvironmentResolver

@Test @MainActor func environmentSelectPersistsAndResolves() async throws {
    let defaults = try makeDefaults()
    let store = EnvironmentStore(defaults: defaults)
    let prod = APIEnvironment(name: "Prod", baseURL: try #require(URL(string: "https://prod.example.com")))
    let staging = APIEnvironment(name: "Staging", baseURL: try #require(URL(string: "https://staging.example.com")))
    store.register([prod, staging], for: .default)
    store.select(staging, for: .default)

    #expect(store.selected[.default] == staging)
    let resolved = EnvironmentResolver.baseURL(
        for: .default,
        default: try #require(URL(string: "https://fallback.example.com")),
        defaults: defaults
    )
    #expect(resolved == staging.baseURL)
}

@Test @MainActor func environmentSelectEmitsChange() async throws {
    let defaults = try makeDefaults()
    let store = EnvironmentStore(defaults: defaults)
    let prod = APIEnvironment(name: "Prod", baseURL: try #require(URL(string: "https://prod.example.com")))
    let staging = APIEnvironment(name: "Staging", baseURL: try #require(URL(string: "https://staging.example.com")))
    store.register([prod, staging], for: .default)

    var iterator = store.changes().makeAsyncIterator()
    store.select(staging, for: .default)
    let change = await iterator.next()
    #expect(change?.environment == staging)
    #expect(change?.clientID == .default)
}

@Test @MainActor func environmentChangesReachEverySubscriberIndependently() async throws {
    let store = EnvironmentStore(defaults: try makeDefaults())
    let prod = APIEnvironment(name: "Prod", baseURL: try #require(URL(string: "https://prod.example.com")))
    let staging = APIEnvironment(name: "Staging", baseURL: try #require(URL(string: "https://staging.example.com")))
    store.register([prod, staging], for: .default)

    let first = store.changes()
    let second = store.changes()
    store.select(staging, for: .default)

    var firstIterator = first.makeAsyncIterator()
    var secondIterator = second.makeAsyncIterator()
    #expect(await firstIterator.next()?.environment == staging)
    #expect(await secondIterator.next()?.environment == staging)
}

@Test @MainActor func reselectingTheActiveEnvironmentDoesNotBroadcast() async throws {
    let store = EnvironmentStore(defaults: try makeDefaults())
    let prod = APIEnvironment(name: "Prod", baseURL: try #require(URL(string: "https://prod.example.com")))
    let staging = APIEnvironment(name: "Staging", baseURL: try #require(URL(string: "https://staging.example.com")))
    store.register([prod, staging], for: .default)

    var iterator = store.changes().makeAsyncIterator()
    store.select(prod, for: .default)      // already active (seeded by register) → no event
    store.select(staging, for: .default)   // real switch → the FIRST event observed

    #expect(await iterator.next()?.environment == staging)
}

@Test @MainActor func removingTheActiveCustomEnvironmentBroadcastsTheFallback() async throws {
    let store = EnvironmentStore(defaults: try makeDefaults())
    let prod = APIEnvironment(name: "Prod", baseURL: try #require(URL(string: "https://prod.example.com")))
    let local = APIEnvironment(name: "Local", baseURL: try #require(URL(string: "http://localhost:8080")), isCustom: true)
    store.register([prod], for: .default)
    store.addCustom(local, for: .default)
    store.select(local, for: .default)

    var iterator = store.changes().makeAsyncIterator()
    store.removeCustom(local, for: .default)

    #expect(store.selected[.default] == prod)
    #expect(await iterator.next()?.environment == prod)
}

@Test @MainActor func resolverFallsBackBeforeAnySelection() throws {
    let fallback = try #require(URL(string: "https://fallback.example.com"))
    let resolved = EnvironmentResolver.baseURL(for: .default, default: fallback, defaults: try makeDefaults())
    #expect(resolved == fallback)
}

// MARK: - Helpers

private func entry(url: String) -> NetworkLogEntry {
    NetworkLogEntry(method: "GET", url: url, requestHeaders: [:], statusCode: 200, duration: .zero, responseBodyPreview: nil, errorDescription: nil)
}

private func transportRequest(method: String, url: String) throws -> TransportRequest {
    var request = URLRequest(url: try #require(URL(string: url)))
    request.httpMethod = method
    return TransportRequest(urlRequest: request, options: RequestOptions())
}

private func makeRegistry() throws -> MockRegistry {
    MockRegistry(defaults: try makeDefaults())
}

private func makeDefaults() throws -> UserDefaultsService {
    let suite = try #require(UserDefaults(suiteName: "pal.debug.tests.\(UUID().uuidString)"))
    return UserDefaultsService(defaults: suite)
}
