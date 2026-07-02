import UserNotifications

extension DeliveredNotification {

    /// Extracts the `Sendable` essentials from the system notification.
    init(_ notification: UNNotification) {
        self.init(
            id: notification.request.identifier,
            title: notification.request.content.title,
            userInfo: notification.request.content.userInfo.stringValues
        )
    }
}
