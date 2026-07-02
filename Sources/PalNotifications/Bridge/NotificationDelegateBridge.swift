import Foundation
import UserNotifications

/// Occupies the `UNUserNotificationCenterDelegate` seat and forwards the system
/// callbacks as `Sendable` values — extracted *before* leaving the delegate
/// context, since the `UN` classes must not cross isolation boundaries.
final class NotificationDelegateBridge: NSObject, UNUserNotificationCenterDelegate {

    private let onResponse: @Sendable (NotificationResponse) -> Void
    private let presentation: @Sendable (DeliveredNotification) -> NotificationPresentation

    init(
        onResponse: @escaping @Sendable (NotificationResponse) -> Void,
        presentation: @escaping @Sendable (DeliveredNotification) -> NotificationPresentation
    ) {
        self.onResponse = onResponse
        self.presentation = presentation
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        onResponse(NotificationResponse(response))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        presentation(DeliveredNotification(notification)).unOptions
    }
}
