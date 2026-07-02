import Foundation
import PalNotifications

/// The showcase's notification values — app-defined static factories, per the
/// "foundation ships mechanisms; apps ship values" law.
extension LocalNotification {

    /// Fired immediately by the "Notify now" action; tapping it deep-links to user 1.
    static var demoSpotlight: LocalNotification {
        LocalNotification(
            id: "demo-spotlight",
            title: String(localized: "User spotlight"),
            body: String(localized: "Leanne Graham posted — tap to open her profile."),
            userInfo: ["userID": "1"]
        )
    }

    /// Scheduled 5 seconds out; background the app to see the banner.
    static var demoReminder: LocalNotification {
        LocalNotification(
            id: "demo-reminder",
            title: String(localized: "Reminder"),
            body: String(localized: "Scheduled 5 seconds ago — tap to open user 2."),
            userInfo: ["userID": "2"]
        )
    }
}
