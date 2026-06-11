/// Conform domain errors to control exactly how they appear to users.
///
/// ```swift
/// extension UsersError: PresentableErrorConvertible {
///     var presentableError: PresentableError {
///         switch self {
///         case .notFound: PresentableError(title: …, message: …, isRetryable: false)
///         case .network:  .generic
///         }
///     }
/// }
/// ```
public protocol PresentableErrorConvertible {

    /// The user-facing presentation of this error.
    var presentableError: PresentableError { get }
}
