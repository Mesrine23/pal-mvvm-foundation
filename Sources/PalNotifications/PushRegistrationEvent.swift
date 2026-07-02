/// The outcome of an APNs registration attempt — observed via
/// ``NotificationService/pushEvents``.
public enum PushRegistrationEvent: Sendable, Equatable {

    /// Registration succeeded; forward the token to your push backend.
    case registered(PushToken)

    /// Registration failed (missing APNs entitlement, no network, or a simulator
    /// without APNs support).
    case failed(message: String)
}
