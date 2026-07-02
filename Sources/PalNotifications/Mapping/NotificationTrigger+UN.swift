import Foundation
import UserNotifications

extension NotificationTrigger {

    /// The system trigger; `nil` delivers immediately.
    var unTrigger: UNNotificationTrigger? {
        switch self {
        case .immediate:
            nil
        case .after(let duration):
            UNTimeIntervalNotificationTrigger(
                timeInterval: max(duration.timeInterval, 0.1),
                repeats: false
            )
        case .at(let components, let repeats):
            UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        }
    }
}

private extension Duration {

    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
