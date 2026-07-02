import UserNotifications

extension NotificationOptions {

    /// The `UNAuthorizationOptions` equivalent.
    var unOptions: UNAuthorizationOptions {
        var out: UNAuthorizationOptions = []
        if contains(.alert) { out.insert(.alert) }
        if contains(.badge) { out.insert(.badge) }
        if contains(.sound) { out.insert(.sound) }
        if contains(.provisional) { out.insert(.provisional) }
        return out
    }
}
