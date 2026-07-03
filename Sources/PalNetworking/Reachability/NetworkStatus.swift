/// The device's network condition, as observed by ``ReachabilityMonitor``.
public struct NetworkStatus: Sendable, Equatable {

    /// Whether the network path is satisfied (requests can be attempted).
    public let isOnline: Bool

    /// Whether the path is expensive (cellular, personal hotspot).
    public let isExpensive: Bool

    /// Whether the path is constrained (Low Data Mode).
    public let isConstrained: Bool

    /// Creates a status.
    public init(isOnline: Bool, isExpensive: Bool = false, isConstrained: Bool = false) {
        self.isOnline = isOnline
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}
