import Foundation
import Observation

/// Observes the device's network condition for **UX affordances** — offline
/// banners, "waiting for connection" states, deferring heavy work on expensive
/// paths. Create **one** at the composition root and inject it.
///
/// Not a request gate: attempt requests regardless and let failures surface
/// through the normal error path — preflighting reachability races reality.
///
/// ```swift
/// // SwiftUI reads the observable status directly:
/// if !reachability.status.isOnline { OfflineBanner() }
///
/// // Or react to changes:
/// for await status in reachability.statusUpdates { … }
/// ```
@MainActor @Observable
public final class ReachabilityMonitor {

    /// The latest known status. Starts **optimistically online** until the first
    /// path update lands (moments after creation), so offline UI never flashes
    /// at launch.
    public private(set) var status = NetworkStatus(isOnline: true)

    @ObservationIgnored private let backend: any NetworkPathMonitoring
    @ObservationIgnored private var observers: [UUID: AsyncStream<NetworkStatus>.Continuation] = [:]

    /// Creates the monitor and starts observing immediately.
    public convenience init() {
        self.init(backend: SystemPathMonitor())
    }

    init(backend: any NetworkPathMonitoring) {
        self.backend = backend
        backend.start { [weak self] status in
            Task { @MainActor in self?.receive(status) }
        }
    }

    deinit {
        backend.cancel()
    }

    /// A live stream of status **changes**. Each access returns an independent
    /// subscription that immediately yields the current status (it is state,
    /// not an event), then every change — duplicates are filtered.
    public var statusUpdates: AsyncStream<NetworkStatus> {
        let (stream, continuation) = AsyncStream.makeStream(of: NetworkStatus.self)
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { _ in
            Task { @MainActor [weak self] in self?.observers[id] = nil }
        }
        continuation.yield(status)
        return stream
    }

    func receive(_ new: NetworkStatus) {
        guard new != status else { return }
        status = new
        for observer in observers.values {
            observer.yield(new)
        }
    }
}
