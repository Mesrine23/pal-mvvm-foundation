import Foundation

/// What the user sees when something fails: a localized title, message, and
/// whether offering Retry makes sense. The last link of the error chain
/// (`NetworkError` → domain error → `PresentableError`).
public struct PresentableError: Sendable, Equatable {

    /// The short, user-facing headline.
    public let title: String

    /// The user-facing explanation.
    public let message: String

    /// Whether retrying the operation could plausibly succeed.
    public let isRetryable: Bool

    /// Creates a presentable error.
    /// - Parameters:
    ///   - title: The user-facing headline.
    ///   - message: The user-facing explanation.
    ///   - isRetryable: Whether to offer Retry. Defaults to `true`.
    public init(title: String, message: String, isRetryable: Bool = true) {
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }

    /// Maps any error: ``PresentableErrorConvertible`` errors provide their own
    /// presentation; everything else falls back to ``generic``.
    public init(from error: any Error) {
        if let convertible = error as? PresentableErrorConvertible {
            self = convertible.presentableError
        } else {
            self = .generic
        }
    }

    /// The localized fallback for unmapped errors (ships in English and Greek).
    public static var generic: PresentableError {
        PresentableError(
            title: String(localized: "error.generic.title", bundle: .module),
            message: String(localized: "error.generic.message", bundle: .module),
            isRetryable: true
        )
    }
}
