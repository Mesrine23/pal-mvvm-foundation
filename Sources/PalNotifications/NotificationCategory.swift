/// A notification category: an app-defined id plus its action buttons. Link a
/// ``LocalNotification`` to it via ``LocalNotification/categoryID`` (or an APNs
/// payload via its `category` field), and register the set once at launch with
/// ``NotificationService/setCategories(_:)``.
public struct NotificationCategory: Sendable, Equatable {

    /// The app-defined identifier.
    public let id: String

    /// The action buttons shown on the expanded notification.
    public let actions: [NotificationAction]

    /// Creates a category.
    public init(id: String, actions: [NotificationAction]) {
        self.id = id
        self.actions = actions
    }
}
