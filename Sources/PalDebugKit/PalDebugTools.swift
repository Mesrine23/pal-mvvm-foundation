import Foundation
import PalNetworking
import PalPersistence
#if canImport(UIKit)
import SwiftUI
#endif

/// The composition root and entry point for Pal's debug suite.
///
/// Activation is **runtime + default-OFF**: nothing happens until ``enable(environments:for:)``
/// is called (the consumer app does this behind its own `DEBUGKIT` compilation flag).
/// Insert ``inspectorInterceptor`` and ``mockInterceptor`` outermost in the client's
/// chain; route the client's `baseURLProvider` through ``EnvironmentResolver``; observe
/// ``environmentChanges`` to run your reset on a switch; and present via ``present()``.
@MainActor
public final class PalDebugTools {

    /// The shared instance.
    public static let shared = PalDebugTools()

    /// Whether the suite has been enabled this session (default `false`).
    public private(set) var isEnabled = false

    let logStore = NetworkLogStore()
    let mockRegistry = MockRegistry()
    let environmentStore = EnvironmentStore()

    private init() {}

    /// Turns the suite on and registers a client's environments.
    /// - Parameters:
    ///   - environments: The selectable environments (empty if you only want Logs/Mocks).
    ///   - clientID: The client they belong to. Defaults to ``ClientID/default``.
    public func enable(environments: [APIEnvironment] = [], for clientID: ClientID = .default) {
        isEnabled = true
        if !environments.isEmpty {
            environmentStore.register(environments, for: clientID)
        }
    }

    /// The network inspector — insert it **outermost** in the client's chain.
    public var inspectorInterceptor: any Interceptor { DebugInspectorInterceptor(store: logStore) }

    /// The response mocker — insert it just inside the inspector.
    public var mockInterceptor: any Interceptor { MockInterceptor(registry: mockRegistry) }

    /// Emits whenever the active environment changes; observe it to run your reset.
    /// Each access returns an **independent subscription** — safe to observe from
    /// several tasks, and safe to resubscribe after an observing task was cancelled.
    public var environmentChanges: AsyncStream<EnvironmentChanged> { environmentStore.changes() }

    #if canImport(UIKit)
    private let window = DebugWindow()

    /// Presents the debug menu in an overlay window above all app content.
    public func present() {
        present { EmptyView() }
    }

    /// Presents the debug menu with extra app-supplied tabs appended.
    public func present<ExtraTabs: View>(@ViewBuilder extraTabs: @escaping () -> ExtraTabs) {
        guard isEnabled else { return }
        window.present(
            rootView: PalDebugMenu(
                logStore: logStore,
                mockRegistry: mockRegistry,
                environmentStore: environmentStore,
                onClose: { [weak self] in self?.dismiss() },
                extraTabs: extraTabs
            )
        )
    }

    /// Dismisses the debug menu.
    public func dismiss() {
        window.dismiss()
    }
    #endif
}
