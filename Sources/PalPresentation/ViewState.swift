/// The universal screen state: what a screen's async content can be at any moment,
/// with impossible combinations unrepresentable.
///
/// `loading` and `failed` carry the previous value so pull-to-refresh keeps content
/// on screen instead of flashing a spinner, and a failed refresh can show a banner
/// over stale data instead of destroying a good screen.
///
/// ```swift
/// switch viewModel.state {
/// case .idle, .loading(previous: nil):           LoadingView()
/// case .loading(previous: let value?):           content(value).overlay { ProgressView() }
/// case .loaded(let value):                       content(value)
/// case .failed(let error, previous: nil):        ErrorView(error) { viewModel.refresh() }
/// case .failed(let error, previous: let value?): content(value).withErrorBanner(error)
/// }
/// ```
public enum ViewState<Value: Sendable>: Sendable {

    /// Nothing has happened yet.
    case idle

    /// A load is running; `previous` is the last good value, when one exists.
    case loading(previous: Value?)

    /// Content is on screen.
    case loaded(Value)

    /// The load failed; `previous` is the last good value, when one exists.
    case failed(PresentableError, previous: Value?)
}

public extension ViewState {

    /// The most recent good value regardless of state, or `nil` when none exists.
    var value: Value? {
        switch self {
        case .idle: nil
        case .loading(let previous): previous
        case .loaded(let value): value
        case .failed(_, let previous): previous
        }
    }

    /// `true` while a load is running.
    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    /// The current failure, or `nil` outside `failed`.
    var error: PresentableError? {
        if case .failed(let error, _) = self { error } else { nil }
    }
}

extension ViewState: Equatable where Value: Equatable {}
