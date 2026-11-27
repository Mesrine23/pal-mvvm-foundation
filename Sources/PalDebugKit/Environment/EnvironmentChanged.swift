/// Broadcast when the active environment for a client changes. The app observes
/// ``PalDebugTools/environmentChanges`` and runs its own reset (cancel in-flight
/// work, then end the session as its logout does: `TokenProvider.logOut()`, clear
/// caches, reset navigation) — the foundation only signals.
public struct EnvironmentChanged: Sendable, Equatable {

    /// The client whose environment changed.
    public let clientID: ClientID

    /// The newly selected environment.
    public let environment: APIEnvironment

    /// Creates the event.
    public init(clientID: ClientID, environment: APIEnvironment) {
        self.clientID = clientID
        self.environment = environment
    }
}
