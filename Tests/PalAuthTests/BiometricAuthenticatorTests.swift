import Foundation
import LocalAuthentication
import Testing
@testable import PalAuth

/// `@unchecked Sendable` justification: all mutable state is `NSLock`-guarded;
/// the spy only records the call and replays a configured result.
private final class SpyEvaluator: BiometricEvaluating, @unchecked Sendable {

    private let lock = NSLock()
    private var _biometry: BiometryKind
    private var _result: Result<Bool, any Error>
    private var _lastReason: String?
    private var _lastFallbackFlag: Bool?
    private var _lastFallbackTitle: String?

    init(biometry: BiometryKind = .faceID, result: Result<Bool, any Error> = .success(true)) {
        _biometry = biometry
        _result = result
    }

    var lastReason: String? { lock.withLock { _lastReason } }
    var lastFallbackFlag: Bool? { lock.withLock { _lastFallbackFlag } }
    var lastFallbackTitle: String? { lock.withLock { _lastFallbackTitle } }

    func availableBiometry() -> BiometryKind {
        lock.withLock { _biometry }
    }

    func evaluate(reason: String, allowingPasscodeFallback: Bool, fallbackTitle: String?) async throws -> Bool {
        try lock.withLock {
            _lastReason = reason
            _lastFallbackFlag = allowingPasscodeFallback
            _lastFallbackTitle = fallbackTitle
            return try _result.get()
        }
    }
}

@Suite("BiometricAuthenticator")
struct BiometricAuthenticatorTests {

    @Test("Reports the available biometry from the evaluator")
    func availabilityPassesThrough() {
        let authenticator = BiometricAuthenticator(backend: SpyEvaluator(biometry: .opticID))
        #expect(authenticator.availableBiometry == .opticID)
    }

    @Test("Success authenticates and passes reason, fallback flag, and title through")
    func successPassesParameters() async throws {
        let spy = SpyEvaluator(result: .success(true))
        let authenticator = BiometricAuthenticator(backend: spy)

        let outcome = try await authenticator.authenticate(
            reason: "Unlock",
            allowingPasscodeFallback: true,
            fallbackTitle: "Use password"
        )

        #expect(outcome == .authenticated)
        #expect(spy.lastReason == "Unlock")
        #expect(spy.lastFallbackFlag == true)
        #expect(spy.lastFallbackTitle == "Use password")
    }

    @Test("Cancellation is an outcome, never an error")
    func cancellationNeverThrows() async throws {
        for code in [LAError.userCancel, .systemCancel, .appCancel] {
            let authenticator = BiometricAuthenticator(backend: SpyEvaluator(result: .failure(LAError(code))))
            #expect(try await authenticator.authenticate(reason: "Unlock") == .cancelled)
        }
    }

    @Test("The fallback button surfaces as an outcome")
    func fallbackIsAnOutcome() async throws {
        let authenticator = BiometricAuthenticator(backend: SpyEvaluator(result: .failure(LAError(.userFallback))))
        #expect(try await authenticator.authenticate(reason: "Unlock") == .fallbackRequested)
    }

    @Test("System failures map to typed BiometricErrors")
    func failuresMapToTypedErrors() async {
        let cases: [(LAError.Code, BiometricError)] = [
            (.biometryNotAvailable, .unavailable),
            (.passcodeNotSet, .unavailable),
            (.biometryNotEnrolled, .notEnrolled),
            (.biometryLockout, .lockedOut),
            (.authenticationFailed, .failed),
        ]
        for (code, expected) in cases {
            let authenticator = BiometricAuthenticator(backend: SpyEvaluator(result: .failure(LAError(code))))
            do {
                _ = try await authenticator.authenticate(reason: "Unlock")
                Issue.record("expected \(expected) for \(code)")
            } catch {
                #expect(error == expected)
            }
        }
    }

    @Test("Unknown errors carry their description")
    func unknownErrorsCarryDescription() async {
        let underlying = NSError(domain: "test", code: 1)
        let authenticator = BiometricAuthenticator(backend: SpyEvaluator(result: .failure(underlying)))
        do {
            _ = try await authenticator.authenticate(reason: "Unlock")
            Issue.record("expected .underlying")
        } catch {
            guard case .underlying = error else {
                Issue.record("expected .underlying, got \(error)")
                return
            }
        }
    }
}
