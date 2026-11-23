/// Owns token access and **single-flight refresh**: when N requests have their
/// token rejected concurrently, one network refresh runs and every caller awaits
/// it — or none, while a ``TransientRefreshFailure/retryAfter`` quiet period lasts.
///
/// The guarantee holds because the in-flight check and assignment happen with no
/// suspension point between them, so the actor can never create a second task
/// while one is registered. Callers that arrive during a refresh join it via
/// actor reentrancy — that interleaving is the design.
///
/// Observe ``events`` from the root coordinator: `.loggedOut` means the session
/// is gone and the app should present login.
public actor TokenProvider {

    enum RefreshOutcome: Sendable {
        case token(String)
        case ended(AuthError)
        case kept(NetworkError)
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
    private var inFlight: Task<String, any Error>?
    private var quietPeriod: QuietPeriod?
    private let continuation: AsyncStream<AuthEvent>.Continuation

    /// Auth lifecycle notifications. Single-consumer: iterate from one place
    /// (the root coordinator).
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

    /// Refreshes the token pair, coalescing concurrent callers into one network call
    /// (none while a ``TransientRefreshFailure/retryAfter`` quiet period lasts).
    /// - Returns: The fresh access token.
    /// - Throws: ``AuthError/notAuthenticated`` when no session exists, or
    ///   ``AuthError/refreshFailed`` when the refresh fails; both clear the store
    ///   and emit ``AuthEvent/loggedOut``. A refresh that fails with
    ///   ``TransientRefreshFailure`` also throws ``AuthError/refreshFailed``, but
    ///   keeps the session and emits nothing.
    public func refresh() async throws(AuthError) -> String {
        switch await refreshOutcome() {
        case .token(let token):
            return token
        case .ended(let error):
            throw error
        case .kept:
            throw .refreshFailed
        }
    }

    func refreshOutcome() async -> RefreshOutcome {
        if let inFlight {
            return await Self.settle(inFlight)
        }
        let task = Task { try await self.performRefresh() }
        inFlight = task
        defer { inFlight = nil }
        return await Self.settle(task)
    }

    private static func settle(_ task: Task<String, any Error>) async -> RefreshOutcome {
        do {
            return .token(try await task.value)
        } catch let error as AuthError {
            return .ended(error)
        } catch let failure as TransientRefreshFailure {
            return .kept(failure.networkError)
        } catch {
            return .ended(.refreshFailed)
        }
    }

    private func performRefresh() async throws -> String {
        guard let refreshToken = await store.tokens()?.refreshToken else {
            await signOut()
            throw AuthError.notAuthenticated
        }
        if let quietPeriod, quietPeriod.covers(refreshToken) {
            throw TransientRefreshFailure(quietPeriod.error)
        }
        let tokens: AuthTokens
        do {
            tokens = try await refresher.refresh(using: refreshToken)
        } catch let failure as TransientRefreshFailure {
            quietPeriod = QuietPeriod(after: failure, refreshToken: refreshToken)
            throw failure
        } catch {
            await signOut()
            throw AuthError.refreshFailed
        }
        await store.save(tokens)
        quietPeriod = nil
        continuation.yield(.refreshed)
        return tokens.accessToken
    }

    private func signOut() async {
        await store.clear()
        continuation.yield(.loggedOut)
    }
}
