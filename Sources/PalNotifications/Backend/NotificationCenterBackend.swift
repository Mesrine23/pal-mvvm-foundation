import UserNotifications

/// The seam over `UNUserNotificationCenter` — the system center requires a real
/// app host, so unit tests substitute a spy while ``SystemNotificationCenter``
/// is the runtime implementation.
@MainActor
protocol NotificationCenterBackend: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removePending(ids: [String])
    func removeAllPending()
    func pendingIDs() async -> [String]
    func removeDelivered(ids: [String])
    func setBadgeCount(_ count: Int) async throws
    func setCategories(_ categories: Set<UNNotificationCategory>)
    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?)
}
