import LocalAuthentication

/// The seam over `LAContext` — the system prompt can't run in unit tests, so
/// tests substitute a stub while ``SystemBiometricEvaluator`` is the runtime
/// implementation.
protocol BiometricEvaluating: Sendable {
    func availableBiometry() -> BiometryKind
    func evaluate(reason: String, allowingPasscodeFallback: Bool, fallbackTitle: String?) async throws -> Bool
}

/// The runtime evaluator. A **fresh `LAContext` per call** — contexts cache
/// their evaluation state, and reuse is the classic stale-Face-ID pitfall.
struct SystemBiometricEvaluator: BiometricEvaluating {

    func availableBiometry() -> BiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .touchID: return .touchID
        case .faceID: return .faceID
        case .opticID: return .opticID
        case .none: return .none
        @unknown default: return .none
        }
    }

    func evaluate(reason: String, allowingPasscodeFallback: Bool, fallbackTitle: String?) async throws -> Bool {
        let context = LAContext()
        if let fallbackTitle {
            context.localizedFallbackTitle = fallbackTitle
        }
        let policy: LAPolicy = allowingPasscodeFallback
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics
        return try await context.evaluatePolicy(policy, localizedReason: reason)
    }
}
