import Foundation
import Testing
@testable import PalNetworking

@Suite("TokenProvider late token rejections")
struct LateRejectionTests {

    @Test("Rejections that overlap a refresh share it")
    func overlappingRejectionsShareOneRefresh() async throws {
        let gate = Gate()
        let refresher = GatedRefresher(gate: gate)
        let provider = TokenProvider(store: GatedTokenStore(stalePair), refresher: refresher)
        let backend = HoldingBackend(holding: 4, accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let calls = (1...4).map { index in startCall { try await client.send(Request<Data>(path: "/items/\(index)")) } }
        #expect(await waitUntil { await backend.heldCount == 4 })
        await backend.release()
        #expect(await waitUntil { await backend.rejections == 4 })
        await gate.open()
        for call in calls {
            #expect(await waitUntil { await call.isDone })
            #expect(await call.failure == nil)
        }

        #expect(await refresher.attempts == 1)
        #expect(await backend.calls.filter { $0.authorization == "Bearer access-1" }.count == 4)
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("A late rejection retries with the replacement, with no second refresh")
    func lateRejectionReusesTheReplacement() async throws {
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: GatedTokenStore(stalePair), refresher: refresher)
        let backend = HoldingBackend(holding: 1, accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let slow = startCall { try await client.send(Request<Data>(path: "/slow")) }
        #expect(await waitUntil { await backend.heldCount == 1 })
        _ = try await client.send(Request<Data>(path: "/fast"))
        await backend.release()
        #expect(await waitUntil { await slow.isDone })

        #expect(await slow.failure == nil)
        #expect(await refresher.refreshTokensSent == ["refresh-0"])
        #expect(await backend.calls.last { $0.path == "/slow" }?.authorization == "Bearer access-1")
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("After a login, a rejection of the new token refreshes the new session")
    func aLoginsRejectedTokenRefreshesTheNewSession() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend { $0 == "Bearer access-1" || $0 == "Bearer access-2" }
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        _ = try await client.send(Request<Data>(path: "/first"))
        await store.save(loginPair)
        _ = try await client.send(Request<Data>(path: "/after-login"))

        #expect(await refresher.refreshTokensSent == ["refresh-0", "login-refresh"])
        #expect(await events(of: provider) == [.refreshed, .refreshed])
    }

    @Test("A refresh that returns the same access token lets the next rejection refresh again")
    func aSameTokenRefreshReplacesNothing() async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: validPair), refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), RejectingTransport { _ in tokenRejection }])

        for _ in 1...2 {
            _ = await thrownError { try await client.send(Request<Data>(path: "/items")) }
        }

        #expect(await refresher.attempts == 2)
        #expect(await events(of: provider) == [.refreshed, .refreshed])
    }

    @Test("A late rejection during a second refresh joins it")
    func aLateRejectionDuringASecondRefreshJoinsIt() async throws {
        let secondGate = Gate()
        let refresher = GatedRefresher(gates: [2: secondGate])
        let provider = TokenProvider(store: GatedTokenStore(stalePair), refresher: refresher)
        let backend = HoldingBackend(holding: 1) { path, authorization in
            path == "/fast" ? authorization == "Bearer access-1" : authorization == "Bearer access-2"
        }
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let slow = startCall { try await client.send(Request<Data>(path: "/slow")) }
        #expect(await waitUntil { await backend.heldCount == 1 })
        _ = try await client.send(Request<Data>(path: "/fast"))
        let second = startCall { try await client.send(Request<Data>(path: "/second")) }
        #expect(await waitUntil { await refresher.attempts == 2 })
        await backend.release()
        #expect(await waitUntil { await backend.rejections == 3 })
        // Joining leaves no trace a test can wait for, so the late rejection gets a
        // window to reach the held refresh; one that misses it fails the test.
        try await Task.sleep(for: .milliseconds(200))
        await secondGate.open()
        #expect(await waitUntil { await slow.isDone })
        #expect(await waitUntil { await second.isDone })

        #expect(await slow.failure == nil)
        #expect(await second.failure == nil)
        #expect(await refresher.attempts == 2)
        #expect(await backend.calls.last { $0.path == "/slow" }?.authorization == "Bearer access-2")
    }

    /// Without `logOut()`, a pair the app saves itself looks like the same session,
    /// so the late call is retried in it. Apps log out before saving another user's.
    @Test("A token the app replaced itself refreshes the current session")
    func aTokenTheAppReplacedItselfRefreshesTheCurrentSession() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(holding: 1, accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let oldCall = startCall { try await client.send(Request<Data>(path: "/old")) }
        #expect(await waitUntil { await backend.heldCount == 1 })
        await store.save(AuthTokens(accessToken: "access-other", refreshToken: "refresh-other"))
        await backend.release()
        #expect(await waitUntil { await oldCall.isDone })

        #expect(await oldCall.failure == nil)
        #expect(await refresher.refreshTokensSent == ["refresh-other"])
        #expect(await backend.calls.last?.authorization == "Bearer access-1")
        #expect(await events(of: provider) == [.refreshed])
    }
}
