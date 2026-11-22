/// Conform domain errors to control exactly how they appear to users. With the
/// error in a Domain package that links nothing, the app conforms it:
///
/// ```swift
/// extension UsersError: @retroactive PresentableErrorConvertible {
///     public var presentableError: PresentableError {
///         switch self {
///         case .notFound: PresentableError(title: String(localized: .usersNotFoundTitle), message: …, isRetryable: false)
///         case .network:  .generic
///         }
///     }
/// }
/// ```
///
/// `@retroactive` belongs only across packages, the witness is `public`, and the
/// conformance isn't `@MainActor`: mapping also runs off the main actor, where an
/// isolated conformance is missed and the error maps to ``PresentableError/generic``.
public protocol PresentableErrorConvertible {

    /// The user-facing presentation of this error.
    var presentableError: PresentableError { get }
}
