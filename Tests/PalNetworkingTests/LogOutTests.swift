import Foundation
import Testing
@testable import PalNetworking

@Suite("TokenProvider.logOut()")
struct LogOutTests {

    @Test("Login is a store save; logOut() emits nothing, and the next call carries no token")
    func loginIsASaveAndLogOutEmitsNothing() async throws {
        let store = GatedTokenStore(nil)
        let provider = TokenProvider(store: store, refresher: GatedRefresher())
        let backend = HoldingBackend { _ in true }
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        await store.save(loginPair)
        _ = try await client.send(Request<Data>(path: "/after-login"))
        await provider.logOut()
        _ = try await client.send(Request<Data>(path: "/after-logout"))

        #expect(await backend.calls.map(\.authorization) == ["Bearer login-access", nil])
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [])
    }

    @Test("logOut() during the refresher's call drops the refresh")
    func logOutDuringTheRefresherCallDropsTheRefresh() async throws {
        let gate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate)
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend(accepts: acceptsRefreshedTokens)])

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await provider.logOut()
        await gate.open()
        #expect(await waitUntil { await call.isDone })

        #expect(await call.failure?.statusCode == 401)
        #expect(await store.tokens() == nil)
        #expect(await store.saves.isEmpty)
        #expect(await events(of: provider) == [])
    }

    @Test("logOut() during the refresh's save leaves the store empty")
    func logOutDuringTheSaveLeavesTheStoreEmpty() async throws {
        let gate = Gate()
        let saveGate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate)
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend(accepts: acceptsRefreshedTokens)])
        await store.holdNextSave(until: saveGate)

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await gate.open()
        #expect(await waitUntil { await store.isSaveHeld })
        let logout = Task { await provider.logOut() }
        #expect(await waitUntil { await store.clearCount == 1 })
        await saveGate.open()
        await logout.value
        #expect(await waitUntil { await call.isDone })

        #expect(await call.failure?.statusCode == 401)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [])
    }

    @Test("A login right after logOut() survives an older refresh that was still saving")
    func aLoginRightAfterLogOutSurvivesAnOlderRefreshStillSaving() async throws {
        let gate = Gate()
        let saveGate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate)
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend(accepts: acceptsRefreshedTokens)])
        await store.holdNextSave(until: saveGate)

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await gate.open()
        #expect(await waitUntil { await store.isSaveHeld })
        let logout = Task { await provider.logOut() }
        #expect(await waitUntil { await store.clearCount == 1 })
        await saveGate.open()
        await logout.value
        await store.save(loginPair)
        #expect(await waitUntil { await call.isDone })

        #expect(await store.tokens() == loginPair)
        #expect(await events(of: provider) == [])
    }

    @Test("logOut() twice in a row during a refresh leaves the store empty and emits nothing")
    func logOutTwiceInARow() async throws {
        let gate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate)
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend(accepts: acceptsRefreshedTokens)])

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await provider.logOut()
        await provider.logOut()
        await gate.open()
        #expect(await waitUntil { await call.isDone })

        #expect(await call.failure?.statusCode == 401)
        #expect(await store.tokens() == nil)
        #expect(await store.clearCount == 2)
        #expect(await events(of: provider) == [])
    }

    @Test("A refresher failure after logOut() emits nothing")
    func aRefresherFailureAfterLogOutEmitsNothing() async throws {
        let gate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate, failure: { _ in URLError(.badServerResponse) })
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend(accepts: acceptsRefreshedTokens)])

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await provider.logOut()
        await gate.open()
        #expect(await waitUntil { await call.isDone })

        #expect(await call.failure?.statusCode == 401)
        #expect(await store.clearCount == 1)
        #expect(await events(of: provider) == [])
    }

    @Test("A transient failure after logOut() is dropped too")
    func aTransientFailureAfterLogOutIsDropped() async throws {
        let gate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate, failure: { _ in
            TransientRefreshFailure(.transport(URLError(.timedOut)), retryAfter: .seconds(30))
        })
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend(accepts: acceptsRefreshedTokens)])

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await provider.logOut()
        await gate.open()
        #expect(await waitUntil { await call.isDone })
        await store.save(stalePair)
        let again = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(await call.failure?.statusCode == 401)
        #expect(again?.urlError?.code == .timedOut)
        #expect(await refresher.attempts == 2)
        #expect(await events(of: provider) == [])
    }

    @Test("Calls and direct refreshes waiting on a dropped refresh fail with their own error")
    func waitersOnADroppedRefreshFailWithTheirOwnError() async throws {
        let gate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate)
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let refresh = startRefresh(provider)
        #expect(await waitUntil { await refresher.attempts == 1 })
        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await backend.rejections == 1 })
        await provider.logOut()
        await gate.open()
        #expect(await waitUntil { await refresh.isDone })
        #expect(await waitUntil { await call.isDone })

        #expect(await refresh.failure == .notAuthenticated)
        #expect(await call.failure?.statusCode == 401)
        #expect(await refresher.attempts == 1)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [])
    }

    @Test("logOut() during a failed refresh's sign-out emits nothing, and a login after it survives")
    func logOutDuringASignOutEmitsNothing() async throws {
        let gate = Gate()
        let clearGate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gate: gate, failure: { _ in URLError(.badServerResponse) })
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend(accepts: acceptsRefreshedTokens)])

        let call = startCall { try await client.send(Request<Data>(path: "/items")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await store.holdNextClear(until: clearGate)
        await gate.open()
        #expect(await waitUntil { await store.isClearHeld })
        let logout = Task { await provider.logOut() }
        #expect(await waitUntil { await store.clearCount == 1 })
        await clearGate.open()
        await logout.value
        await store.save(loginPair)
        #expect(await waitUntil { await call.isDone })

        #expect(await call.failure?.statusCode == 401)
        #expect(await store.tokens() == loginPair)
        #expect(await events(of: provider) == [])
    }

    @Test("A call during logOut() goes out without a token and starts nothing")
    func aCallDuringLogOutGoesOutWithoutAToken() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend(accepts: acceptsRefreshedTokens)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])
        let clearGate = Gate()
        await store.holdNextClear(until: clearGate)

        let logout = Task { await provider.logOut() }
        #expect(await waitUntil { await store.isClearHeld })
        let call = startCall { try await client.send(Request<Data>(path: "/during-logout")) }
        #expect(await waitUntil { await call.isDone })
        await clearGate.open()
        await logout.value

        #expect(await call.failure?.statusCode == 401)
        #expect(await backend.calls.map(\.authorization) == [nil])
        #expect(await refresher.attempts == 0)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [])
    }

    @Test("A direct refresh() during logOut() starts nothing")
    func aDirectRefreshDuringLogOutStartsNothing() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let clearGate = Gate()
        await store.holdNextClear(until: clearGate)

        let logout = Task { await provider.logOut() }
        #expect(await waitUntil { await store.isClearHeld })
        let refresh = startRefresh(provider)
        #expect(await waitUntil { await refresh.isDone })
        await clearGate.open()
        await logout.value

        #expect(await refresh.failure == .notAuthenticated)
        #expect(await refresher.attempts == 0)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [])
    }

    @Test("logOut() during a refresh's store read keeps the refresher from being called")
    func logOutDuringTheStoreReadCallsNoRefresher() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let readGate = Gate()
        await store.holdNextRead(until: readGate)

        let refresh = startRefresh(provider)
        #expect(await waitUntil { await store.isReadHeld })
        await provider.logOut()
        await readGate.open()
        #expect(await waitUntil { await refresh.isDone })

        #expect(await refresh.failure == .notAuthenticated)
        #expect(await refresher.attempts == 0)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [])
    }

    @Test("A new session's rejection after logOut() starts its own refresh")
    func aNewSessionsRejectionAfterLogOutStartsItsOwnRefresh() async throws {
        let oldGate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gates: [1: oldGate])
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), HoldingBackend { $0 == "Bearer access-2" }])

        let oldCall = startCall { try await client.send(Request<Data>(path: "/old")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await provider.logOut()
        await store.save(loginPair)
        let newCall = startCall { try await client.send(Request<Data>(path: "/new")) }
        #expect(await waitUntil { await newCall.isDone })
        await oldGate.open()
        #expect(await waitUntil { await oldCall.isDone })

        #expect(await newCall.failure == nil)
        #expect(await oldCall.failure?.statusCode == 401)
        #expect(await refresher.refreshTokensSent == ["refresh-0", "login-refresh"])
        #expect(await store.tokens()?.accessToken == "access-2")
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("A dropped refresh doesn't unregister the one that replaced it")
    func aDroppedRefreshDoesNotUnregisterTheNextOne() async throws {
        let oldGate = Gate()
        let newGate = Gate()
        let store = GatedTokenStore(stalePair)
        let refresher = GatedRefresher(gates: [1: oldGate, 2: newGate])
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = HoldingBackend { $0 == "Bearer access-2" }
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let oldCall = startCall { try await client.send(Request<Data>(path: "/old")) }
        #expect(await waitUntil { await refresher.attempts == 1 })
        await provider.logOut()
        await store.save(loginPair)
        let firstNew = startCall { try await client.send(Request<Data>(path: "/new/1")) }
        #expect(await waitUntil { await refresher.attempts == 2 })
        await oldGate.open()
        #expect(await waitUntil { await oldCall.isDone })
        let secondNew = startCall { try await client.send(Request<Data>(path: "/new/2")) }
        #expect(await waitUntil { await backend.rejections == 3 })
        await newGate.open()
        #expect(await waitUntil { await firstNew.isDone })
        #expect(await waitUntil { await secondNew.isDone })

        #expect(await firstNew.failure == nil)
        #expect(await secondNew.failure == nil)
        #expect(await refresher.attempts == 2)
    }

    /// The quiet period is tied to the refresh token that failed, so only a pair
    /// saved again with that token shows that `logOut()` ended it.
    @Test("logOut() ends the quiet period")
    func logOutEndsTheQuietPeriod() async throws {
        let store = GatedTokenStore(stalePair)
        let refresher = ScriptedRefresher { attempt, _ in
            guard attempt > 1 else {
                throw TransientRefreshFailure(.transport(URLError(.timedOut)), retryAfter: .seconds(30))
            }
            return validPair
        }
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        let kept = await thrownError { try await client.send(Request<Data>(path: "/items")) }
        await provider.logOut()
        await store.save(stalePair)
        let afterLogOut = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(kept?.urlError?.code == .timedOut)
        #expect(afterLogOut == nil)
        #expect(await refresher.attempts == 2)
    }
}
