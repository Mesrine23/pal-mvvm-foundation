/// An action button on a notification, registered through a ``NotificationCategory``.
/// Its ``id`` comes back as ``NotificationResponse/ActionID-swift.enum/custom(_:)``
/// when tapped.
public struct NotificationAction: Sendable, Equatable {

    /// Behavioral flags for the action.
    public struct Options: OptionSet, Sendable {

        public let rawValue: Int

        /// Creates options from a raw value.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Launches the app in the foreground.
        public static let foreground = Options(rawValue: 1 << 0)

        /// Rendered as destructive.
        public static let destructive = Options(rawValue: 1 << 1)

        /// Requires the device to be unlocked.
        public static let authenticationRequired = Options(rawValue: 1 << 2)
    }

    /// The app-defined identifier delivered back on tap.
    public let id: String

    /// The button title (localized by the app).
    public let title: String

    /// Behavioral flags.
    public let options: Options

    /// Creates an action.
    public init(id: String, title: String, options: Options = []) {
        self.id = id
        self.title = title
        self.options = options
    }
}
