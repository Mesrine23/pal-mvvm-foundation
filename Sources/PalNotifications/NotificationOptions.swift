/// The capabilities requested via ``NotificationService/requestAuthorization(_:)``.
public struct NotificationOptions: OptionSet, Sendable {

    public let rawValue: Int

    /// Creates options from a raw value.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Show alerts and banners.
    public static let alert = NotificationOptions(rawValue: 1 << 0)

    /// Update the app icon badge.
    public static let badge = NotificationOptions(rawValue: 1 << 1)

    /// Play sounds.
    public static let sound = NotificationOptions(rawValue: 1 << 2)

    /// Quiet, promptless trial authorization (delivers to Notification Center only).
    public static let provisional = NotificationOptions(rawValue: 1 << 3)

    /// The common request: alert + badge + sound.
    public static let standard: NotificationOptions = [.alert, .badge, .sound]
}
