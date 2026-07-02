import Foundation

/// A local notification the app defines and schedules through ``NotificationService``.
///
/// Apps declare their notifications as static factory extensions — the foundation
/// ships the mechanism, the app the values:
///
/// ```swift
/// extension LocalNotification {
///     static func orderReady(_ order: Order) -> LocalNotification {
///         LocalNotification(
///             id: "order-ready-\(order.id)",
///             title: String(localized: "Your order is ready"),
///             body: order.summary,
///             userInfo: ["orderID": order.id]
///         )
///     }
/// }
/// ```
public struct LocalNotification: Sendable, Identifiable, Equatable {

    /// Stable identifier — scheduling again with the same id replaces the pending
    /// request; also the handle for ``NotificationService/cancelPending(ids:)``.
    public let id: String

    /// The notification title.
    public let title: String

    /// The optional subtitle, shown below the title.
    public let subtitle: String?

    /// The body text.
    public let body: String

    /// The sound played on delivery.
    public let sound: NotificationSound

    /// The badge count to set on delivery (`nil` leaves the badge untouched).
    public let badge: Int?

    /// Links the notification to its ``NotificationCategory`` (action buttons).
    public let categoryID: String?

    /// Groups related notifications into one thread in Notification Center.
    public let threadID: String?

    /// App payload carried through to the tap's ``NotificationResponse``
    /// (deep-link keys, entity ids — string values).
    public let userInfo: [String: String]

    /// Creates a local notification.
    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        body: String,
        sound: NotificationSound = .default,
        badge: Int? = nil,
        categoryID: String? = nil,
        threadID: String? = nil,
        userInfo: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.sound = sound
        self.badge = badge
        self.categoryID = categoryID
        self.threadID = threadID
        self.userInfo = userInfo
    }
}
