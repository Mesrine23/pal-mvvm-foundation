import Foundation

/// The per-screen runner: adopt this and every async load becomes one line, with
/// the five responsibilities handled once — set `.loading` (keeping the previous
/// value), await, map failures to ``PresentableError``, swallow cancellation, and
/// cancel the superseded in-flight load on re-trigger.
///
/// ```swift
/// @MainActor @Observable
/// final class UsersListViewModel: LoadableViewModelProtocol {
///     private(set) var state: ViewState<[User]> = .idle
///     var loadTask: Task<Void, Never>?
///     private let fetchUsers: FetchUsersUseCaseProtocol
///
///     func refresh() { load { try await self.fetchUsers.execute() } }
/// }
/// ```
///
/// ``load(_:)`` owns re-trigger cancellation (search-as-you-type, rapid refresh);
/// SwiftUI's `.task` owns view-lifecycle cancellation via ``performLoad(_:)``.
@MainActor
public protocol LoadableViewModelProtocol: AnyObject {

    /// The screen's content type.
    associatedtype Value: Sendable

    /// The screen state the View renders from.
    var state: ViewState<Value> { get set }

    /// Storage for the in-flight load; managed by ``load(_:)`` and ``cancelLoad()``.
    var loadTask: Task<Void, Never>? { get set }
}

public extension LoadableViewModelProtocol {

    /// Runs the operation through the state machine, cancelling any previous
    /// in-flight load first. Fire-and-forget — callable from buttons, delegates,
    /// or `onAppear`.
    func load(_ operation: @escaping @Sendable () async throws -> Value) {
        loadTask?.cancel()
        state = .loading(previous: state.value)
        loadTask = Task { [weak self] in
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
    /// cancels the work automatically when the view disappears.
    func performLoad(_ operation: @escaping @Sendable () async throws -> Value) async {
        loadTask?.cancel()
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

    /// Cancels any in-flight load without changing state.
    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }
}
