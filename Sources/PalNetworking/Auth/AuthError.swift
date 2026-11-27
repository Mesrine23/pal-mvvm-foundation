/// Failures thrown by ``TokenProvider/refresh()``.
public enum AuthError: Error, Sendable, Equatable {

    /// There's no session to refresh: none is stored, or it ended while the
    /// refresh ran, for example through ``TokenProvider/logOut()``.
    case notAuthenticated

    /// The refresh failed. The session was cleared, unless the failure was a
    /// ``TransientRefreshFailure``, which keeps it.
    case refreshFailed
}
