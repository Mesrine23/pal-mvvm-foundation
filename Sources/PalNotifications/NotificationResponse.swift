/// The user's interaction with a delivered notification (tap, action button,
/// dismiss) — observed via ``NotificationService/responses`` and mapped by the
/// app to routes (ride an id in ``userInfo``, re-fetch in the destination).
public struct NotificationResponse: Sendable, Equatable {

    /// Which interaction happened.
    public enum ActionID: Sendable, Equatable {

        /// The user tapped the notification itself.
        case `default`

        /// The user dismissed it (delivered only for categories that request it).
        case dismiss

        /// A custom action button, by its app-defined ``NotificationAction/id``.
        case custom(String)
    }

    /// The notification's identifier.
    public let notificationID: String

    /// The interaction.
    public let actionID: ActionID

    /// The string values of the payload's `userInfo` (deep-link keys, entity ids).
    public let userInfo: [String: String]

    /// Creates a response.
    public init(notificationID: String, actionID: ActionID, userInfo: [String: String] = [:]) {
        self.notificationID = notificationID
        self.actionID = actionID
        self.userInfo = userInfo
    }
}
