import Foundation
import Observation
import PalPersistence

/// Drives the API-switcher UI and persists the active environment per client.
/// The synchronous read path for request routing lives in ``EnvironmentResolver``;
/// this type owns the observable state and the change broadcast.
@MainActor @Observable
final class EnvironmentStore {

    private(set) var environments: [ClientID: [APIEnvironment]] = [:]
    private(set) var selected: [ClientID: APIEnvironment] = [:]

    @ObservationIgnored private let defaults: UserDefaultsService
    @ObservationIgnored private var observers: [UUID: AsyncStream<EnvironmentChanged>.Continuation] = [:]

    init(defaults: UserDefaultsService = UserDefaultsService()) {
        self.defaults = defaults
        let rawSelected = defaults.get(.palDebugSelectedEnvironments) ?? [:]
        self.selected = rawSelected.reduce(into: [:]) { $0[ClientID($1.key)] = $1.value }
    }

    /// A live stream of environment switches. Every call returns an **independent
    /// subscription** — multiple observers each receive every change, and a new
    /// subscription after a cancelled one starts clean (an `AsyncStream` is unicast
    /// and terminates permanently on cancellation, so sharing one instance would
    /// starve later observers).
    func changes() -> AsyncStream<EnvironmentChanged> {
        let (stream, continuation) = AsyncStream.makeStream(of: EnvironmentChanged.self)
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { _ in
            Task { @MainActor [weak self] in self?.observers[id] = nil }
        }
        return stream
    }

    /// Registers a client's environments (merging any persisted custom ones) and
    /// seeds a selection if none exists yet.
    func register(_ envs: [APIEnvironment], for clientID: ClientID) {
        let custom = (defaults.get(.palDebugCustomEnvironments) ?? [:])[clientID.rawValue] ?? []
        environments[clientID] = envs + custom
        if selected[clientID] == nil, let first = envs.first ?? custom.first {
            selected[clientID] = first
            persistSelected()
        }
    }

    /// Selects an environment and broadcasts the change. Re-selecting the active
    /// environment is a no-op — a broadcast triggers the app's full reset.
    func select(_ environment: APIEnvironment, for clientID: ClientID) {
        guard selected[clientID]?.id != environment.id else { return }
        selected[clientID] = environment
        persistSelected()
        broadcast(EnvironmentChanged(clientID: clientID, environment: environment))
    }

    func addCustom(_ environment: APIEnvironment, for clientID: ClientID) {
        var byClient = defaults.get(.palDebugCustomEnvironments) ?? [:]
        byClient[clientID.rawValue, default: []].append(environment)
        defaults.set(byClient, for: .palDebugCustomEnvironments)
        environments[clientID, default: []].append(environment)
    }

    /// Removes a custom environment. If it was the active one, selection falls back
    /// to the first remaining environment **and broadcasts** — requests already
    /// resolve against the new base URL, so the app's reset must run.
    func removeCustom(_ environment: APIEnvironment, for clientID: ClientID) {
        guard environment.isCustom else { return }
        var byClient = defaults.get(.palDebugCustomEnvironments) ?? [:]
        byClient[clientID.rawValue]?.removeAll { $0.id == environment.id }
        defaults.set(byClient, for: .palDebugCustomEnvironments)
        environments[clientID]?.removeAll { $0.id == environment.id }
        if selected[clientID]?.id == environment.id {
            let fallback = environments[clientID]?.first
            selected[clientID] = fallback
            persistSelected()
            if let fallback {
                broadcast(EnvironmentChanged(clientID: clientID, environment: fallback))
            }
        }
    }

    private func broadcast(_ change: EnvironmentChanged) {
        for observer in observers.values {
            observer.yield(change)
        }
    }

    private func persistSelected() {
        let raw = selected.reduce(into: [String: APIEnvironment]()) { $0[$1.key.rawValue] = $1.value }
        defaults.set(raw, for: .palDebugSelectedEnvironments)
    }
}
