import Network

/// The seam over `NWPathMonitor` — the system monitor can't be driven in unit
/// tests (`NWPath` is not constructible), so tests substitute a spy while
/// ``SystemPathMonitor`` is the runtime implementation.
protocol NetworkPathMonitoring: AnyObject, Sendable {
    func start(onUpdate: @escaping @Sendable (NetworkStatus) -> Void)
    func cancel()
}

/// The runtime backend: an `NWPathMonitor` on its own queue, mapping each
/// path update to a ``NetworkStatus``.
final class SystemPathMonitor: NetworkPathMonitoring {

    private let monitor = NWPathMonitor()

    func start(onUpdate: @escaping @Sendable (NetworkStatus) -> Void) {
        monitor.pathUpdateHandler = { path in
            onUpdate(NetworkStatus(
                isOnline: path.status == .satisfied,
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained
            ))
        }
        monitor.start(queue: DispatchQueue(label: "pal.networking.reachability"))
    }

    func cancel() {
        monitor.cancel()
    }
}
