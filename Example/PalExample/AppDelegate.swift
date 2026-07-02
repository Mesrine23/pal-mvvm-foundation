import UIKit
import PalNotifications

/// The ~5-line UIKit bridge PalNotifications needs for APNs registration: the
/// system delivers the device token (or failure) here, and we forward it into
/// the ``NotificationService`` owned by the composition root.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Assigned by the app shell right after the container is created.
    var notifications: NotificationService?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        notifications?.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        notifications?.handleRegistrationFailure(error)
    }
}
