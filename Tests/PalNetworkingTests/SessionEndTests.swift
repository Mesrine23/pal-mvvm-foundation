import Foundation
import Testing
@testable import PalNetworking

@Suite("TokenProvider session ends")
struct SessionEndTests {

    @Test("With no session, a rejection starts nothing and emits nothing")
    func noSessionRejectionStartsNothing() async throws {
        let store = GatedTokenStore(nil)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend { $0 != nil }
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        for _ in 1...2 {
            let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }
            #expect(error?.statusCode == 401)
        }

        #expect(await backend.calls.allSatisfy { $0.authorization == nil })
        #expect(await refresher.attempts == 0)
        #expect(await store.clearCount == 0)
        #expect(await events(of: provider) == [])
    }

    @Test("A late rejection after a failed refresh starts nothing")
    func lateRejectionAfterAFailedRefreshStartsNothing() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(failure: { _ in NetworkError.transport(URLError(.timedOut)) })
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(holding: 1, accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let slow = startCall { try await client.send(Request<Data>(path: "/slow")) }
        #expect(await waitUntil { await backend.heldCount == 1 })
        let fastError = await thrownError { try await client.send(Request<Data>(path: "/fast")) }
        await backend.release()
        #expect(await waitUntil { await slow.isDone })

        #expect(fastError?.statusCode == 401)
        #expect(await slow.failure?.statusCode == 401)
        #expect(await refresher.attempts == 1)
        #expect(await store.clearCount == 1)
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("Rejections during a failing refresh share it and emit one loggedOut")
    func rejectionsDuringAFailingRefreshShareIt() async throws {
        let gate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate, failure: { _ in URLError(.badServerResponse) })
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(holding: 3, accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let calls = (1...3).map { index in startCall { try await client.send(Request<Data>(path: "/items/\(index)")) } }
        #expect(await waitUntil { await backend.heldCount == 3 })
        await backend.release()
        #expect(await waitUntil { await backend.rejections == 3 })
        await gate.open()
        for call in calls {
            #expect(await waitUntil { await call.isDone })
            #expect(await call.failure?.statusCode == 401)
        }

        #expect(await refresher.attempts == 1)
        #expect(await store.clearCount == 1)
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("A rejection after logOut() starts nothing")
    func rejectionAfterLogOutStartsNothing() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(holding: 1, accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await backend.heldCount == 1 })
        await provider.logOut()
        await backend.release()
        #expect(await waitUntil { await call.isDone })

        #expect(await call.failure?.statusCode == 401)
        #expect(await refresher.attempts == 0)
        #expect(await store.clearCount == 1)
        #expect(await events(of: provider) == [])
    }

    @Test("After a session ended, a new login's rejection refreshes normally")
    func aNewLoginAfterASessionEndedRefreshesNormally() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(failure: { call in
            guard call == 1 else { return nil }
            return URLError(.badServerResponse)
        })
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend { $0 == "Bearer access-2" }])

        let ended = await thrownError { try await client.send(Request<Data>(path: "/items")) }
        await store.save(loginPair)
        let afterLogin = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(ended?.statusCode == 401)
        #expect(afterLogin == nil)
        #expect(await refresher.refreshTokensSent == ["refresh-0", "login-refresh"])
        #expect(await events(of: provider) == [.loggedOut, .refreshed])
    }

    @Test("A direct refresh() with no session still clears the store and emits loggedOut")
    func directRefreshWithNoSessionSignsOut() async throws {
        let store = GatedTokenStore(nil)
        let provider = TokenProvider(store: store, refresher: GatedRefresher())

        await #expect(throws: AuthError.notAuthenticated) {
            try await provider.refresh()
        }

        #expect(await store.clearCount == 1)
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("Direct refresh() calls that share an attempt with no session sign out once")
    func directRefreshesSharingAnAttemptSignOutOnce() async throws {
        let store = GatedTokenStore(nil)
        let provider = TokenProvider(store: store, refresher: GatedRefresher())
        let readGate = Gate()
        await store.holdNextRead(until: readGate)

        let refreshes = (1...5).map { _ in startRefresh(provider) }
        #expect(await waitUntil { await store.isReadHeld })
        // Joining leaves no trace a test can wait for, so the other callers get a
        // window to reach the held attempt; one that misses it fails the test.
        try await Task.sleep(for: .milliseconds(200))
        await readGate.open()
        for refresh in refreshes {
            #expect(await waitUntil { await refresh.isDone })
            #expect(await refresh.failure == .notAuthenticated)
        }

        #expect(await store.clearCount == 1)
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("A call sent without a token starts nothing, even after a login")
    func aTokenlessCallStartsNothingEvenAfterALogin() async throws {
        let store = GatedTokenStore(nil)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(holding: 1) { $0 == "Bearer access-1" }
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await backend.heldCount == 1 })
        await store.save(loginPair)
        await backend.release()
        #expect(await waitUntil { await call.isDone })

        #expect(await call.failure?.statusCode == 401)
        #expect(await refresher.attempts == 0)
        #expect(await backend.calls.map(\.authorization) == [nil])
        #expect(await events(of: provider) == [])
    }

    @Test("An older session's rejection doesn't join the next session's refresh")
    func anOlderSessionsRejectionDoesNotJoinTheNextSessionsRefresh() async throws {
        let gate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate)
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(holding: 1) { $0 == "Bearer access-1" }
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let oldCall = startCall { try await client.send(Request<Data>(path: "/old")) }
        #expect(await waitUntil { await backend.heldCount == 1 })
        await provider.logOut()
        await store.save(loginPair)
        let newCall = startCall { try await client.send(Request<Data>(path: "/new")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await backend.release()
        #expect(await waitUntil { await oldCall.isDone })
        await gate.open()
        #expect(await waitUntil { await newCall.isDone })

        #expect(await oldCall.failure?.statusCode == 401)
        #expect(await newCall.failure == nil)
        #expect(await backend.calls.filter { $0.path == "/old" }.map(\.authorization) == ["Bearer access-0"])
        #expect(await refresher.refreshTokensSent == ["login-refresh"])
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("A call prepared during a failed refresh's sign-out carries no token")
    func aCallPreparedDuringASignOutCarriesNoToken() async throws {
        let gate = Gate()
        let clearGate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate, failure: { _ in URLError(.badServerResponse) })
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let first = startCall { try await client.send(Request<Data>(path: "/first")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await store.holdNextClear(until: clearGate)
        await gate.open()
        #expect(await waitUntil { await store.isClearHeld })
        let during = startCall { try await client.send(Request<Data>(path: "/during-sign-out")) }
        #expect(await waitUntil { await backend.calls.contains { $0.path == "/during-sign-out" } })
        await clearGate.open()
        #expect(await waitUntil { await first.isDone })
        #expect(await waitUntil { await during.isDone })

        #expect(await during.failure?.statusCode == 401)
        #expect(await backend.calls.last { $0.path == "/during-sign-out" }?.authorization == nil)
        #expect(await refresher.attempts == 1)
        #expect(await events(of: provider) == [.loggedOut])
    }
}
