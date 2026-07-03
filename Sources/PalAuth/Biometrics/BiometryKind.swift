/// The biometry a device offers.
public enum BiometryKind: Sendable, Equatable {

    /// No usable biometry (unsupported, unavailable, or not permitted).
    case none

    /// Touch ID.
    case touchID

    /// Face ID.
    case faceID

    /// Optic ID.
    case opticID
}
