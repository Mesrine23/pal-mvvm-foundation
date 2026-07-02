import Foundation
import UserNotifications

extension LocalNotification {

    /// Builds the system request for this notification and trigger.
    func unRequest(trigger: NotificationTrigger) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle {
            content.subtitle = subtitle
        }
        content.body = body
        switch sound {
        case .default:
            content.sound = .default
        case .silent:
            content.sound = nil
        case .named(let name):
            content.sound = UNNotificationSound(named: UNNotificationSoundName(name))
        }
        if let badge {
            content.badge = NSNumber(value: badge)
        }
        if let categoryID {
            content.categoryIdentifier = categoryID
        }
        if let threadID {
            content.threadIdentifier = threadID
        }
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger.unTrigger)
    }
}
