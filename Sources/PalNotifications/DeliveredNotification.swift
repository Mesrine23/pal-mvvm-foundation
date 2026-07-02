/// A notification that arrived while the app was foregrounded — handed to the
/// app's presentation policy to decide how (or whether) to show it.
public struct DeliveredNotification: Sendable, Equatable {

    /// The notification's identifier (a ``LocalNotification/id`` or the APNs id).
    public let id: String

    /// The notification title.
    public let title: String

    /// The string values of the payload's `userInfo`.
    public let userInfo: [String: String]

    /// Creates a delivered-notification summary.
    public init(id: String, title: String, userInfo: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.userInfo = userInfo
    }
}
