import Foundation

/// Drives one async-loaded piece of screen content through the ``ViewState``
/// machine. A ViewModel owns one or more loaders — a screen with several
/// independently-refreshing sections gives each its own `Loader`.
///
/// `load(_:)` handles the five recurring responsibilities once: set `.loading`
/// (keeping the previous value), await, map failures to ``PresentableError``,
/// swallow cancellation, and cancel a superseded in-flight load on re-trigger.
/// `state` is read-only to the outside — only the loader mutates it.
///
/// ```swift
/// @MainActor @Observable
/// final class HomeViewModel {
///     let home = Loader<HomeContent>()
///     private let fetchHome: FetchHomeUseCaseProtocol
///     init(fetchHome: FetchHomeUseCaseProtocol) { self.fetchHome = fetchHome }
///     func load() { home.load { try await self.fetchHome.execute() } }
/// }
/// // View switches on `viewModel.home.state`.
/// ```
@MainActor
@Observable
public final class Loader<Value: Sendable> {

    /// The current state of this content. Read-only externally; mutated only by the loader.
    public private(set) var state: ViewState<Value> = .idle

    private var task: Task<Void, Never>?

    /// Creates an idle loader.
    public init() {}

    /// Runs the operation through the state machine, cancelling any previous
    /// in-flight load first. Fire-and-forget — call from buttons, delegates, or
    /// `onAppear`. Owns re-trigger cancellation (search-as-you-type, rapid refresh).
    public func load(_ operation: @escaping @Sendable () async throws -> Value) {
        task?.cancel()
        state = .loading(previous: state.value)
        task = Task { [weak self] in
            do {
                let value = try await operation()
                guard !Task.isCancelled else { return }
                self?.state = .loaded(value)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.state = .failed(PresentableError(from: error), previous: self.state.value)
            }
        }
    }

    /// The awaitable variant for `.task { }` integration: the view's lifecycle
    /// cancels the work when the view disappears.
    public func performLoad(_ operation: @escaping @Sendable () async throws -> Value) async {
        task?.cancel()
        state = .loading(previous: state.value)
        do {
            let value = try await operation()
            guard !Task.isCancelled else { return }
            state = .loaded(value)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(PresentableError(from: error), previous: state.value)
        }
    }

    /// Reloads in place for **pull-to-refresh**: it does *not* enter `.loading`
    /// (the refresh control is already the indicator) — it keeps the current value
    /// visible and swaps to `.loaded`/`.failed` on completion. Awaitable, so
    /// `.refreshable` waits for it. Driving `.loading` from a `.refreshable` action
    /// instead fights the refresh control ("change the refresh control while it is
    /// not idle") and can drop the first update.
    public func refresh(_ operation: @escaping @Sendable () async throws -> Value) async {
        task?.cancel()
        do {
            let value = try await operation()
            guard !Task.isCancelled else { return }
            state = .loaded(value)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(PresentableError(from: error), previous: state.value)
        }
    }

    /// Cancels any in-flight load without changing state.
    public func cancel() {
        task?.cancel()
        task = nil
    }

    /// Cancels any in-flight load and returns to `.idle` — the affordance behind
    /// a user-facing Cancel button. ``cancel()`` alone leaves the state at
    /// `.loading` (correct for view-lifecycle teardown, where nobody is looking),
    /// which would strand a visible spinner when the screen stays on-screen.
    public func reset() {
        cancel()
        state = .idle
    }
}
