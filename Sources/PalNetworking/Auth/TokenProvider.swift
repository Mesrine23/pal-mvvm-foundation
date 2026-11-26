/// Owns the session's tokens and refreshes them **single-flight**: token
/// rejections that overlap a refresh join it, so they share one refresher call —
/// or none, while a ``TransientRefreshFailure/retryAfter`` quiet period lasts.
/// A rejection of the token the last refresh replaced retries with its
/// replacement; one that carried no token, or whose session has ended since,
/// starts nothing and emits nothing.
///
/// Nothing refreshes ahead of expiry: ``AuthTokens/expiresAt`` is stored, never
/// read. What counts as a rejection is the app's call
/// (``AuthInterceptor/init(tokenProvider:isTokenRejection:)``), and so is which
/// refresh failures keep the session: the refresher throws
/// ``TransientRefreshFailure`` for those, and any other error ends it.
///
/// - **Login:** save the pair with ``TokenStore/save(_:)``. The store is read for
///   every authenticated request, so the next one carries it.
/// - **Logout:** call ``logOut()``, and await it before saving another user's
///   session. It emits nothing.
/// - **A session that ends by itself:** ``events`` emits ``AuthEvent/loggedOut``.
///   Observe it from one place, the root coordinator, and present login.
///
/// Single-flight holds because the in-flight check and assignment happen with no
/// suspension point between them, so the actor never creates a second refresh
/// while one is registered. Callers that arrive during a refresh join it via
/// actor reentrancy — that interleaving is the design.
public actor TokenProvider {

    enum RefreshOutcome: Sendable {
        case token(String)
        case ended(AuthError)
        case kept(NetworkError)
        case noSession(generation: Int)
        case superseded
    }

    struct Credential: Sendable {
        let token: String?
        let generation: Int
    }

    private struct Replacement {
        let replaced: String
        let issued: String
    }

    private struct QuietPeriod {
        let refreshToken: String
        let until: ContinuousClock.Instant
        let error: NetworkError

        init?(after failure: TransientRefreshFailure, refreshToken: String) {
            guard let retryAfter = failure.retryAfter, retryAfter > .zero else {
                return nil
            }
            self.refreshToken = refreshToken
            until = .now + retryAfter
            error = failure.networkError
        }

        func covers(_ refreshToken: String) -> Bool {
            refreshToken == self.refreshToken && ContinuousClock.now < until
        }
    }

    private let store: any TokenStore
    private let refresher: any TokenRefreshService
    private var inFlight: Task<RefreshOutcome, Never>?
    private var quietPeriod: QuietPeriod?
    private var lastReplacement: Replacement?
    private var generation = 0
    private var sessionEndsUnderway = 0
    private var pendingWrite: Task<Void, Never>?
    private let continuation: AsyncStream<AuthEvent>.Continuation

    /// Auth lifecycle notifications, for a single consumer: iterate them from one
    /// place, the root coordinator. A second iterator doesn't get copies — each
    /// event goes to only one of them. Events sent before the iteration starts are
    /// buffered and delivered when it does.
    public nonisolated let events: AsyncStream<AuthEvent>

    /// Creates a token provider.
    /// - Parameters:
    ///   - store: Where tokens persist (Keychain-backed in production via `PalAuth`).
    ///   - refresher: The app's refresh-call implementation.
    public init(store: any TokenStore, refresher: any TokenRefreshService) {
        self.store = store
        self.refresher = refresher
        (events, continuation) = AsyncStream.makeStream(of: AuthEvent.self)
    }

    /// The current access token, or `nil` when logged out.
    public func currentToken() async -> String? {
        await store.tokens()?.accessToken
    }

    /// Ends the session at the app's request, when the user logs out: clears the
    /// stored tokens, ends any quiet period, and makes a refresh that's still
    /// running drop its result. That refresh saves nothing, and a save it already
    /// started is waited for and cleared. The requests waiting on it fail with
    /// their own token rejection, and a later rejection of the ended session's
    /// tokens starts nothing.
    ///
    /// Emits no event: ``AuthEvent/loggedOut`` is for a session that ended by
    /// itself. Run the app's end-of-session cleanup where it calls this, the same
    /// cleanup as for `.loggedOut`.
    ///
    /// Until it returns, requests go out without a token and no refresh starts.
    /// Await it before saving another session with ``TokenStore/save(_:)``:
    /// without it, a late call of the old session can be retried with the new
    /// one's token.
    public func logOut() async {
        let racingWrite = pendingWrite
        generation &+= 1
        sessionEndsUnderway += 1
        defer { sessionEndsUnderway -= 1 }
        inFlight = nil
        lastReplacement = nil
        quietPeriod = nil
        await store.clear()
        if let racingWrite {
            await racingWrite.value
            await store.clear()
        }
    }

    /// Refreshes the token pair now, joining a refresh that's already running.
    /// ``AuthInterceptor`` doesn't need it: it refreshes on a token rejection.
    /// - Returns: The fresh access token.
    /// - Throws: ``AuthError/refreshFailed`` when the refresh fails. That ends the
    ///   session — the store is cleared and ``AuthEvent/loggedOut`` emitted —
    ///   unless the refresher threw ``TransientRefreshFailure`` or a quiet period
    ///   it asked for still lasts, which keeps the session and emits nothing.
    ///   ``AuthError/notAuthenticated`` when there's no session: with none stored,
    ///   it emits ``AuthEvent/loggedOut`` as a session end does; while a session is
    ///   ending, or once ``logOut()`` dropped this refresh, it emits nothing.
    public func refresh() async throws(AuthError) -> String {
        switch await sharedRefresh() {
        case .token(let token):
            return token
        case .ended(let error):
            throw error
        case .kept:
            throw .refreshFailed
        case .noSession(let sessionGeneration):
            // Callers that shared the attempt sign out once.
            if sessionGeneration == generation {
                await signOut()
            }
            throw .notAuthenticated
        case .superseded:
            throw .notAuthenticated
        }
    }

    func credential() async -> Credential {
        // The generation is read first, and no token is handed out while a session
        // ends, so a rejection of this call never acts on a later generation.
        let generation = generation
        guard sessionEndsUnderway == 0 else {
            return Credential(token: nil, generation: generation)
        }
        return Credential(token: await store.tokens()?.accessToken, generation: generation)
    }

    func refreshOutcome(rejecting credential: Credential) async -> RefreshOutcome {
        guard let rejected = credential.token else {
            return .noSession(generation: generation)
        }
        guard credential.generation == generation else {
            return .superseded
        }
        if inFlight == nil, let lastReplacement, lastReplacement.replaced == rejected {
            return .token(lastReplacement.issued)
        }
        return await sharedRefresh()
    }

    private func sharedRefresh() async -> RefreshOutcome {
        if let inFlight {
            return await inFlight.value
        }
        // A refresh started while a session ends could save that session again.
        guard sessionEndsUnderway == 0 else {
            return .superseded
        }
        let task = Task { await self.performRefresh() }
        inFlight = task
        defer {
            if inFlight == task {
                inFlight = nil
            }
        }
        return await task.value
    }

    private func performRefresh() async -> RefreshOutcome {
        let started = generation
        let stored = await store.tokens()
        guard generation == started else {
            return .superseded
        }
        guard let stored else {
            return .noSession(generation: started)
        }
        if let quietPeriod, quietPeriod.covers(stored.refreshToken) {
            return .kept(quietPeriod.error)
        }
        let fresh: AuthTokens
        do {
            fresh = try await refresher.refresh(using: stored.refreshToken)
        } catch let failure as TransientRefreshFailure {
            guard generation == started else {
                return .superseded
            }
            quietPeriod = QuietPeriod(after: failure, refreshToken: stored.refreshToken)
            return .kept(failure.networkError)
        } catch {
            guard generation == started else {
                return .superseded
            }
            await signOut()
            return .ended(.refreshFailed)
        }
        guard generation == started else {
            return .superseded
        }
        await write { await $0.save(fresh) }
        guard generation == started else {
            return .superseded
        }
        if fresh.accessToken != stored.accessToken {
            lastReplacement = Replacement(replaced: stored.accessToken, issued: fresh.accessToken)
        }
        quietPeriod = nil
        continuation.yield(.refreshed)
        return .token(fresh.accessToken)
    }

    private func signOut() async {
        generation &+= 1
        let ending = generation
        sessionEndsUnderway += 1
        defer { sessionEndsUnderway -= 1 }
        lastReplacement = nil
        await write { await $0.clear() }
        // No event if `logOut()` came in between: the app is ending the session itself.
        if generation == ending {
            continuation.yield(.loggedOut)
        }
    }

    // A task, so that `logOut()` can wait for a write that a refresh started.
    private func write(_ change: @escaping @Sendable (any TokenStore) async -> Void) async {
        let task = Task { await change(store) }
        pendingWrite = task
        await task.value
        if pendingWrite == task {
            pendingWrite = nil
        }
    }
}
