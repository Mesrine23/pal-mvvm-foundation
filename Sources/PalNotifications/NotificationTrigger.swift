import Foundation

/// When a scheduled ``LocalNotification`` fires.
public enum NotificationTrigger: Sendable, Equatable {

    /// Delivers now — the fire-now path for a client-side notification an
    /// app action triggers.
    case immediate

    /// Delivers once after a delay (values ≤ 0 are clamped to 0.1 seconds).
    case after(Duration)

    /// Delivers when the calendar components next match; `repeats` re-arms it
    /// on every match (e.g. hour+minute for a daily reminder).
    case at(DateComponents, repeats: Bool)
}
