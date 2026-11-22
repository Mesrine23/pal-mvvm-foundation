import Foundation
import PalNotifications

/// The showcase's notification values — app-defined static factories, per the
/// "foundation ships mechanisms; apps ship values" law.
extension LocalNotification {

    /// Fired immediately by the "Notify now" action; tapping it deep-links to user 1.
    static var demoSpotlight: LocalNotification {
        LocalNotification(
            id: "demo-spotlight",
            title: String(localized: .notificationSpotlightTitle),
            body: String(localized: .notificationSpotlightBody),
            userInfo: ["userID": "1"]
        )
    }

    /// Scheduled 5 seconds out; background the app to see the banner.
    static var demoReminder: LocalNotification {
        LocalNotification(
            id: "demo-reminder",
            title: String(localized: .notificationReminderTitle),
            body: String(localized: .notificationReminderBody),
            userInfo: ["userID": "2"]
        )
    }
}
