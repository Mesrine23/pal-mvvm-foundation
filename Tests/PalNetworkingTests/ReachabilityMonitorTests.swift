import Foundation
import Testing
@testable import PalNetworking

/// `@unchecked Sendable` justification: the captured callback is guarded by an
/// `NSLock`; the spy only bridges test-driven updates into the monitor.
private final class SpyPathMonitor: NetworkPathMonitoring, @unchecked Sendable {

    private let lock = NSLock()
    private var onUpdate: (@Sendable (NetworkStatus) -> Void)?
    private(set) var cancelled = false

    func start(onUpdate: @escaping @Sendable (NetworkStatus) -> Void) {
        lock.withLock { self.onUpdate = onUpdate }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }

    func send(_ status: NetworkStatus) {
        let callback = lock.withLock { onUpdate }
        callback?(status)
    }
}

@MainActor
@Suite("ReachabilityMonitor")
struct ReachabilityMonitorTests {

    @Test("Starts optimistically online, then tracks path updates")
    func tracksUpdates() async throws {
        let spy = SpyPathMonitor()
        let monitor = ReachabilityMonitor(backend: spy)
        #expect(monitor.status.isOnline)

        spy.send(NetworkStatus(isOnline: false))
        try await Task.sleep(for: .milliseconds(50))

        #expect(monitor.status.isOnline == false)
    }

    @Test("Expensive and constrained flags carry through")
    func flagsCarryThrough() async throws {
        let spy = SpyPathMonitor()
        let monitor = ReachabilityMonitor(backend: spy)

        spy.send(NetworkStatus(isOnline: true, isExpensive: true, isConstrained: true))
        try await Task.sleep(for: .milliseconds(50))

        #expect(monitor.status.isExpensive)
        #expect(monitor.status.isConstrained)
    }

    @Test("Every subscription yields the current status immediately")
    func replaysCurrentStatus() async {
        let monitor = ReachabilityMonitor(backend: SpyPathMonitor())

        var iterator = monitor.statusUpdates.makeAsyncIterator()

        #expect(await iterator.next() == NetworkStatus(isOnline: true))
    }

    @Test("Changes broadcast to every subscriber; duplicates are filtered")
    func broadcastsAndDedupes() async {
        let spy = SpyPathMonitor()
        let monitor = ReachabilityMonitor(backend: spy)
        let first = monitor.statusUpdates
        let second = monitor.statusUpdates

        let offline = NetworkStatus(isOnline: false)
        monitor.receive(offline)
        monitor.receive(offline)
        monitor.receive(NetworkStatus(isOnline: true))

        var firstIterator = first.makeAsyncIterator()
        _ = await firstIterator.next()
        #expect(await firstIterator.next() == offline)
        #expect(await firstIterator.next() == NetworkStatus(isOnline: true))

        var secondIterator = second.makeAsyncIterator()
        _ = await secondIterator.next()
        #expect(await secondIterator.next() == offline)
    }
}
