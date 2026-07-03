/// Why a biometric evaluation could not succeed. Cancellation is deliberately
/// **not** an error — it comes back as ``BiometricOutcome/cancelled``.
public enum BiometricError: Error, Sendable, Equatable {

    /// Biometry is not available on this device (or the app lacks permission).
    case unavailable

    /// The user has not enrolled Face ID / Touch ID (or set a passcode).
    case notEnrolled

    /// Too many failed attempts — biometry is locked until passcode unlock.
    case lockedOut

    /// The biometric match failed.
    case failed

    /// Another system error, carrying its description.
    case underlying(message: String)
}
