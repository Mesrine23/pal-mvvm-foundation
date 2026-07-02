import Foundation

/// The APNs device token — forward ``hexString`` to your push backend.
public struct PushToken: Sendable, Equatable {

    /// The raw token bytes.
    public let data: Data

    /// The token as lowercase hex — the wire format push backends expect.
    public var hexString: String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// Wraps a raw APNs device token.
    public init(data: Data) {
        self.data = data
    }
}
