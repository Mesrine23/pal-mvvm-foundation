import LocalAuthentication

/// Face ID / Touch ID gating behind one typed call — Pal ships the machinery
/// (fresh-context evaluation, error mapping, the cancellation rule); the app
/// ships the values (the localized reason, what "fallback" means).
///
/// ```swift
/// let biometrics = BiometricAuthenticator()
///
/// switch try await biometrics.authenticate(reason: String(localized: "Unlock your vault")) {
/// case .authenticated:     unlock()
/// case .cancelled:         break                        // never an error
/// case .fallbackRequested: showPasswordSheet()
/// }
/// // BiometricError (.unavailable / .notEnrolled / .lockedOut / .failed) → .appAlert
/// ```
public struct BiometricAuthenticator: Sendable {

    private let backend: any BiometricEvaluating

    /// Creates an authenticator.
    public init() {
        self.init(backend: SystemBiometricEvaluator())
    }

    init(backend: any BiometricEvaluating) {
        self.backend = backend
    }

    /// The biometry the device currently offers — checked fresh on every read
    /// (enrollment and permission can change while the app runs).
    public var availableBiometry: BiometryKind {
        backend.availableBiometry()
    }

    /// Shows the biometric prompt.
    /// - Parameters:
    ///   - reason: The localized sentence shown in the prompt (an app value).
    ///   - allowingPasscodeFallback: When `true`, the system offers the device
    ///     passcode itself and ``BiometricOutcome/fallbackRequested`` never occurs.
    ///   - fallbackTitle: A custom title for the fallback button (localized by the app).
    /// - Returns: The outcome; cancellation is an outcome, never a thrown error.
    public func authenticate(
        reason: String,
        allowingPasscodeFallback: Bool = false,
        fallbackTitle: String? = nil
    ) async throws(BiometricError) -> BiometricOutcome {
        do {
            let success = try await backend.evaluate(
                reason: reason,
                allowingPasscodeFallback: allowingPasscodeFallback,
                fallbackTitle: fallbackTitle
            )
            return success ? .authenticated : .cancelled
        } catch {
            switch (error as? LAError)?.code {
            case .userCancel, .systemCancel, .appCancel:
                return .cancelled
            case .userFallback:
                return .fallbackRequested
            case .biometryNotAvailable, .passcodeNotSet:
                throw .unavailable
            case .biometryNotEnrolled:
                throw .notEnrolled
            case .biometryLockout:
                throw .lockedOut
            case .authenticationFailed:
                throw .failed
            default:
                throw .underlying(message: error.localizedDescription)
            }
        }
    }
}
