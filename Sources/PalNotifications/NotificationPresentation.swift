/// How a notification arriving while the app is **foregrounded** is presented —
/// returned by the policy closure the app passes to ``NotificationService``.
public struct NotificationPresentation: OptionSet, Sendable {

    public let rawValue: Int

    /// Creates a presentation from a raw value.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Show the banner.
    public static let banner = NotificationPresentation(rawValue: 1 << 0)

    /// Play the sound.
    public static let sound = NotificationPresentation(rawValue: 1 << 1)

    /// Apply the badge.
    public static let badge = NotificationPresentation(rawValue: 1 << 2)

    /// Add to Notification Center's list.
    public static let list = NotificationPresentation(rawValue: 1 << 3)

    /// The default policy: banner + sound.
    public static let standard: NotificationPresentation = [.banner, .sound]

    /// Suppress the notification entirely.
    public static let hidden: NotificationPresentation = []
}
