import Foundation

/// A transient, non-blocking confirmation — the toast half of the ACTION channel:
/// `.appAlert` interrupts for failures that need acknowledgement; a toast confirms
/// without stealing focus ("Saved", "Scheduled"). Apps declare their toasts as
/// static factory extensions:
///
/// ```swift
/// extension AppToast {
///     static var saved: AppToast {
///         AppToast(kind: .success, title: String(localized: "Saved"))
///     }
/// }
/// ```
public struct AppToast: Identifiable, Sendable, Equatable {

    /// The semantic flavor — drives the icon and tint.
    public enum Kind: Sendable, Equatable {
        case info
        case success
        case warning
        case error
    }

    /// Unique per toast — presenting a new value replaces the current one.
    public let id: UUID

    /// The semantic flavor.
    public let kind: Kind

    /// The one-line headline (already localized by the app).
    public let title: String

    /// Optional supporting line.
    public let message: String?

    /// How long the toast stays before auto-dismissing.
    public let duration: Duration

    /// Creates a toast.
    public init(
        kind: Kind = .info,
        title: String,
        message: String? = nil,
        duration: Duration = .seconds(3)
    ) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.message = message
        self.duration = duration
    }
}
