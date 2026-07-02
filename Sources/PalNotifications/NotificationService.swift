import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// The notifications facade: permission, local scheduling (immediate / delayed /
/// calendar), APNs registration plumbing, category registration, and the response
/// and push-event streams. Create **one** at the composition root and inject it.
///
/// ```swift
/// let notifications = NotificationService()
/// let granted = try await notifications.requestAuthorization()
/// try await notifications.schedule(.orderReady(order))                        // fire now
/// try await notifications.schedule(.dailyDigest, trigger: .at(nineAM, repeats: true))
/// ```
///
/// Create the service **before the app finishes launching** (a stored property of
/// the composition root the shell owns) — creation claims the notification-center
/// delegate seat, so cold-start taps are captured; they buffer until ``responses``
/// is first observed.
@MainActor
public final class NotificationService {

    private let backend: any NotificationCenterBackend
    private var bridge: NotificationDelegateBridge?
    private var responseObservers: [UUID: AsyncStream<NotificationResponse>.Continuation] = [:]
    private var pushObservers: [UUID: AsyncStream<PushRegistrationEvent>.Continuation] = [:]
    private var bufferedResponses: [NotificationResponse] = []
    private var latestPushEvent: PushRegistrationEvent?

    /// Creates the service and claims the notification-center delegate seat.
    /// - Parameter foregroundPresentation: How a notification arriving while the
    ///   app is foregrounded is shown. Defaults to banner + sound.
    public convenience init(
        foregroundPresentation: @escaping @Sendable (DeliveredNotification) -> NotificationPresentation = { _ in .standard }
    ) {
        self.init(backend: SystemNotificationCenter(), foregroundPresentation: foregroundPresentation)
    }

    init(
        backend: any NotificationCenterBackend,
        foregroundPresentation: @escaping @Sendable (DeliveredNotification) -> NotificationPresentation = { _ in .standard }
    ) {
        self.backend = backend
        let bridge = NotificationDelegateBridge(
            onResponse: { [weak self] response in
                Task { @MainActor in self?.receive(response) }
            },
            presentation: foregroundPresentation
        )
        self.bridge = bridge
        backend.setDelegate(bridge)
    }

    // MARK: - Authorization

    /// Prompts for (or quietly extends, with `.provisional`) notification permission.
    /// - Returns: Whether the user granted the request.
    public func requestAuthorization(_ options: NotificationOptions = .standard) async throws -> Bool {
        try await backend.requestAuthorization(options: options.unOptions)
    }

    /// The current permission state.
    public func authorizationStatus() async -> NotificationAuthorizationStatus {
        NotificationAuthorizationStatus(await backend.authorizationStatus())
    }

    // MARK: - Local notifications

    /// Schedules a local notification. `.immediate` (the default) delivers now —
    /// the client-side notification an app action triggers. Scheduling again with
    /// the same ``LocalNotification/id`` replaces the pending request.
    public func schedule(_ notification: LocalNotification, trigger: NotificationTrigger = .immediate) async throws {
        try await backend.add(notification.unRequest(trigger: trigger))
    }

    /// Cancels pending (not-yet-delivered) notifications by id.
    public func cancelPending(ids: [String]) {
        backend.removePending(ids: ids)
    }

    /// Cancels every pending notification.
    public func cancelAllPending() {
        backend.removeAllPending()
    }

    /// The ids of all pending notifications.
    public func pendingIDs() async -> [String] {
        await backend.pendingIDs()
    }

    /// Removes already-delivered notifications from Notification Center by id.
    public func removeDelivered(ids: [String]) {
        backend.removeDelivered(ids: ids)
    }

    /// Sets the app icon badge (`0` clears it).
    public func setBadgeCount(_ count: Int) async throws {
        try await backend.setBadgeCount(count)
    }

    // MARK: - Categories

    /// Registers the app's notification categories (action buttons) — call once at launch.
    public func setCategories(_ categories: [NotificationCategory]) {
        backend.setCategories(Set(categories.map(\.unCategory)))
    }

    // MARK: - Responses

    /// The user's notification interactions (taps, action buttons, dismissals).
    /// Each access returns an **independent subscription**; interactions delivered
    /// before the first subscriber (cold-start taps) are buffered and replayed to it.
    public var responses: AsyncStream<NotificationResponse> {
        let (stream, continuation) = AsyncStream.makeStream(of: NotificationResponse.self)
        let id = UUID()
        responseObservers[id] = continuation
        continuation.onTermination = { _ in
            Task { @MainActor [weak self] in self?.responseObservers[id] = nil }
        }
        for buffered in bufferedResponses {
            continuation.yield(buffered)
        }
        bufferedResponses.removeAll()
        return stream
    }

    func receive(_ response: NotificationResponse) {
        if responseObservers.isEmpty {
            bufferedResponses.append(response)
        } else {
            for observer in responseObservers.values {
                observer.yield(response)
            }
        }
    }

    // MARK: - Push registration

    #if canImport(UIKit)
    /// Kicks off APNs registration; the outcome arrives on ``pushEvents`` once the
    /// app-side `UIApplicationDelegateAdaptor` forwards the system callbacks into
    /// ``handleDeviceToken(_:)`` / ``handleRegistrationFailure(_:)``.
    @available(iOSApplicationExtension, unavailable)
    public func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    #endif

    /// Forward `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` here.
    public func handleDeviceToken(_ deviceToken: Data) {
        broadcastPush(.registered(PushToken(data: deviceToken)))
    }

    /// Forward `application(_:didFailToRegisterForRemoteNotificationsWithError:)` here.
    public func handleRegistrationFailure(_ error: any Error) {
        broadcastPush(.failed(message: error.localizedDescription))
    }

    /// APNs registration outcomes. Each access returns an **independent
    /// subscription** that replays the latest outcome (the token is state, and it
    /// often arrives before the UI subscribes).
    public var pushEvents: AsyncStream<PushRegistrationEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: PushRegistrationEvent.self)
        let id = UUID()
        pushObservers[id] = continuation
        continuation.onTermination = { _ in
            Task { @MainActor [weak self] in self?.pushObservers[id] = nil }
        }
        if let latestPushEvent {
            continuation.yield(latestPushEvent)
        }
        return stream
    }

    private func broadcastPush(_ event: PushRegistrationEvent) {
        latestPushEvent = event
        for observer in pushObservers.values {
            observer.yield(event)
        }
    }
}
