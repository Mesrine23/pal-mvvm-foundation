import Foundation
import PalPresentation

/// A popup over an intact screen — the channel for ACTION failures and for
/// questions before an action (load failures belong to `ViewState`; a
/// confirmation after an action is an ``AppToast``). Apps declare their
/// specific alerts as static factory extensions:
///
/// ```swift
/// extension AppAlert {
///     static func confirmDelete(name: String, onConfirm: @escaping @MainActor @Sendable () -> Void) -> AppAlert {
///         AppAlert(
///             kind: .warning,
///             title: String(localized: .deleteTitle),
///             message: String(localized: .deleteMessage(name)),
///             primary: AlertAction(String(localized: .deleteConfirm), role: .destructive, action: onConfirm),
///             secondary: .cancel()
///         )
///     }
/// }
/// ```
public struct AppAlert: Identifiable, Sendable {

    /// The alert's semantic flavor, driving its icon and accent.
    public enum Kind: Sendable {

        /// Neutral information.
        case info

        /// A positive outcome.
        case success

        /// A caution, or a question before a destructive action.
        case warning

        /// A failure.
        case error
    }

    /// Unique per presentation.
    public let id: UUID

    /// The alert's semantic flavor.
    public let kind: Kind

    /// The already-localized headline.
    public let title: String

    /// The already-localized explanation.
    public let message: String

    /// The primary button.
    public let primary: AlertAction

    /// The optional secondary button (`nil` → single-button popup).
    public let secondary: AlertAction?

    /// Creates an alert.
    /// - Parameters:
    ///   - kind: The semantic flavor. Defaults to `.info`.
    ///   - title: The already-localized headline.
    ///   - message: The already-localized explanation.
    ///   - primary: The primary button.
    ///   - secondary: The optional secondary button. Defaults to `nil`.
    public init(
        kind: Kind = .info,
        title: String,
        message: String,
        primary: AlertAction,
        secondary: AlertAction? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.message = message
        self.primary = primary
        self.secondary = secondary
    }

    /// Bridges an action failure into an error popup with a localized OK button.
    /// - Parameters:
    ///   - error: The failure to present.
    ///   - onDismiss: Runs when the user dismisses. Defaults to nothing.
    public static func error(
        _ error: PresentableError,
        onDismiss: @escaping @MainActor @Sendable () -> Void = {}
    ) -> AppAlert {
        AppAlert(
            kind: .error,
            title: error.title,
            message: error.message,
            primary: AlertAction(String(localized: "common.ok", bundle: .module), action: onDismiss)
        )
    }
}
