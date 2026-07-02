/// The app's notification permission, mapped from the system status so callers
/// never import `UserNotifications` for the basics.
public enum NotificationAuthorizationStatus: Sendable, Equatable {

    /// The user has not been asked yet.
    case notDetermined

    /// The user declined — only the system Settings app can re-enable.
    case denied

    /// Full authorization.
    case authorized

    /// Quiet, trial delivery granted by ``NotificationOptions/provisional``
    /// without a prompt.
    case provisional

    /// Short-lived authorization (App Clips).
    case ephemeral
}
