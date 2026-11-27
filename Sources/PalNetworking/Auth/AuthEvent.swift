/// Auth lifecycle notifications streamed by ``TokenProvider/events``. The app's
/// own login and logout emit neither.
public enum AuthEvent: Sendable, Equatable {

    /// Tokens were refreshed successfully.
    case refreshed

    /// The session ended by itself — a refresh failed with any error but
    /// ``TransientRefreshFailure``, or a direct ``TokenProvider/refresh()`` found no
    /// session. The store is already cleared: run the app's end-of-session cleanup,
    /// the same as for its own ``TokenProvider/logOut()``, and route to login.
    case loggedOut
}
