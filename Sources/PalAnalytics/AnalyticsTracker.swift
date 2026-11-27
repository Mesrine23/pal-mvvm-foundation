/// The provider-agnostic analytics seam. ViewModels track through this protocol;
/// SDK adapters (Firebase, Mixpanel, …) conform **in the app** at the composition
/// root — SDKs never enter the foundation.
///
/// Conventions: ViewModels track (never Views, never repositories); call
/// ``reset()`` at every session end — the app's own logout and
/// `AuthEvent.loggedOut` alike.
public protocol AnalyticsTracker: Sendable {

    /// Records an event.
    func track(_ event: AnalyticsEvent)

    /// Associates subsequent events with a user, or clears the association with `nil`.
    func identify(userID: String?)

    /// Sets a persistent user property, or removes it with `nil`.
    func setUserProperty(_ value: String?, for key: String)

    /// Clears all user association and state — call at every session end.
    func reset()
}
