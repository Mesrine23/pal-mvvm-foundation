import UserNotifications

extension NotificationResponse {

    /// Extracts the `Sendable` essentials from the system response.
    init(_ response: UNNotificationResponse) {
        let actionID: ActionID = switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier: .default
        case UNNotificationDismissActionIdentifier: .dismiss
        default: .custom(response.actionIdentifier)
        }
        self.init(
            notificationID: response.notification.request.identifier,
            actionID: actionID,
            userInfo: response.notification.request.content.userInfo.stringValues
        )
    }
}
