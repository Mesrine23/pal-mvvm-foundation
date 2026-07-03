/// How a biometric prompt concluded when nothing went *wrong*.
public enum BiometricOutcome: Sendable, Equatable {

    /// The user authenticated.
    case authenticated

    /// The user (or the system) dismissed the prompt — never an error, per the
    /// foundation's cancellation rule; treat it as "do nothing".
    case cancelled

    /// The user tapped the fallback button — present your fallback path
    /// (only occurs when passcode fallback is disallowed).
    case fallbackRequested
}
