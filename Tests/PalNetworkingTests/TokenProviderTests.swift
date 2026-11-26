import Foundation
import Testing
@testable import PalNetworking

actor InMemoryTokenStore: TokenStore {

    private var stored: AuthTokens?

    init(tokens: AuthTokens?) {
        stored = tokens
    }

    func tokens() async -> AuthTokens? { stored }
    func save(_ tokens: AuthTokens) async { stored = tokens }
    func clear() async { stored = nil }
}

actor CountingRefresher: TokenRefreshService {

    private(set) var refreshCount = 0
    private let delay: Duration
    private let fails: Bool

    init(delay: Duration = .milliseconds(50), fails: Bool = false) {
        self.delay = delay
        self.fails = fails
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        refreshCount += 1
        try? await Task.sleep(for: delay)
        if fails {
            throw URLError(.badServerResponse)
        }
        return AuthTokens(accessToken: "fresh-\(refreshCount)", refreshToken: "next-refresh")
    }
}

@Suite("TokenProvider single-flight refresh")
struct TokenProviderTests {

    private func makeLoggedInProvider(refresher: CountingRefresher) -> TokenProvider {
        TokenProvider(
            store: InMemoryTokenStore(tokens: AuthTokens(accessToken: "stale", refreshToken: "valid")),
            refresher: refresher
        )
    }

    @Test("N concurrent refreshes produce exactly ONE network refresh")
    func concurrentRefreshesCoalesce() async throws {
        let refresher = CountingRefresher()
        let provider = makeLoggedInProvider(refresher: refresher)

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await provider.refresh() }
            }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }

        #expect(await refresher.refreshCount == 1)
        #expect(Set(tokens) == ["fresh-1"])
    }

    @Test("Sequential refreshes each hit the network")
    func sequentialRefreshesRunSeparately() async throws {
        let refresher = CountingRefresher(delay: .milliseconds(5))
        let provider = makeLoggedInProvider(refresher: refresher)

        _ = try await provider.refresh()
        _ = try await provider.refresh()

        #expect(await refresher.refreshCount == 2)
    }

    @Test("Successful refresh saves tokens and emits .refreshed")
    func successSavesAndEmitsRefreshed() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "stale", refreshToken: "valid"))
        let provider = TokenProvider(store: store, refresher: CountingRefresher(delay: .zero))

        let token = try await provider.refresh()

        #expect(token == "fresh-1")
        #expect(await store.tokens()?.accessToken == "fresh-1")
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("Failed refresh clears the session and emits .loggedOut")
    func failureClearsSessionAndEmitsLoggedOut() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "stale", refreshToken: "valid"))
        let provider = TokenProvider(store: store, refresher: CountingRefresher(delay: .zero, fails: true))

        await #expect(throws: AuthError.refreshFailed) {
            try await provider.refresh()
        }
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("Missing refresh token throws .notAuthenticated and emits .loggedOut")
    func missingRefreshTokenThrowsNotAuthenticated() async throws {
        let provider = TokenProvider(
            store: InMemoryTokenStore(tokens: nil),
            refresher: CountingRefresher(delay: .zero)
        )

        await #expect(throws: AuthError.notAuthenticated) {
            try await provider.refresh()
        }
        #expect(await events(of: provider) == [.loggedOut])
    }
}
