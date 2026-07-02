import UserNotifications

extension NotificationCategory {

    /// The `UNNotificationCategory` equivalent.
    var unCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: id,
            actions: actions.map(\.unAction),
            intentIdentifiers: [],
            options: []
        )
    }
}
