/// Failures thrown by ``TokenProvider/refresh()``.
public enum AuthError: Error, Sendable, Equatable {

    /// No refresh token exists — the user must log in.
    case notAuthenticated

    /// The refresh failed. The session was cleared, unless the failure was a
    /// ``TransientRefreshFailure``, which keeps it.
    case refreshFailed
}
