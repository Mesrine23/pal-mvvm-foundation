import UserNotifications

extension NotificationAction {

    /// The `UNNotificationAction` equivalent.
    var unAction: UNNotificationAction {
        var unOptions: UNNotificationActionOptions = []
        if options.contains(.foreground) { unOptions.insert(.foreground) }
        if options.contains(.destructive) { unOptions.insert(.destructive) }
        if options.contains(.authenticationRequired) { unOptions.insert(.authenticationRequired) }
        return UNNotificationAction(identifier: id, title: title, options: unOptions)
    }
}
