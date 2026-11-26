/// Persists the auth token pair. `PalAuth` ships the Keychain-backed
/// implementation; tests use an in-memory conformance.
///
/// ``TokenProvider`` reads the store for every authenticated request, so saving
/// the pair a login call returns is the login.
public protocol TokenStore: Sendable {

    /// The currently stored tokens, or `nil` when logged out.
    func tokens() async -> AuthTokens?

    /// Stores a token pair, replacing any previous one. With a ``TokenProvider``,
    /// await ``TokenProvider/logOut()`` first when the pair belongs to another
    /// user.
    func save(_ tokens: AuthTokens) async

    /// Removes the stored tokens. With a ``TokenProvider``, log out through
    /// ``TokenProvider/logOut()`` instead: it also stops a refresh that's still
    /// running from saving its tokens back.
    func clear() async
}
