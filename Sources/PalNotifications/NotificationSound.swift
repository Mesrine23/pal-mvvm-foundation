/// The sound a ``LocalNotification`` plays on delivery.
public enum NotificationSound: Sendable, Equatable {

    /// The system default notification sound.
    case `default`

    /// Silent delivery.
    case silent

    /// A custom sound file bundled with the app (e.g. `"chime.caf"`).
    case named(String)
}
