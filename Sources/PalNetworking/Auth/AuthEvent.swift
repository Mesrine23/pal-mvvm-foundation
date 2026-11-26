/// Auth lifecycle notifications streamed by ``TokenProvider/events``.
public enum AuthEvent: Sendable, Equatable {

    /// Tokens were refreshed successfully.
    case refreshed

    /// The session ended by itself — a refresh failed with any error but
    /// ``TransientRefreshFailure``, or a direct ``TokenProvider/refresh()`` found no
    /// session — route to login. ``TokenProvider/logOut()`` doesn't emit it.
    case loggedOut
}
