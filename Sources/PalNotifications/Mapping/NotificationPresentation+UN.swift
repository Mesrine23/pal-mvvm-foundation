import UserNotifications

extension NotificationPresentation {

    /// The `UNNotificationPresentationOptions` equivalent.
    var unOptions: UNNotificationPresentationOptions {
        var out: UNNotificationPresentationOptions = []
        if contains(.banner) { out.insert(.banner) }
        if contains(.sound) { out.insert(.sound) }
        if contains(.badge) { out.insert(.badge) }
        if contains(.list) { out.insert(.list) }
        return out
    }
}
