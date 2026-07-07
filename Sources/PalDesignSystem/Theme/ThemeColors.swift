import SwiftUI

/// The theme's semantic color slots — names describe roles, never values.
public struct ThemeColors: Sendable {

    /// The screen background.
    public var background: Color

    /// Elevated surfaces: cards and grouped content.
    public var surface: Color

    /// Floating chrome one level above ``surface``: sheets, alerts, toasts.
    /// Defaults to ``surface``, so themes that don't distinguish the two
    /// change nothing.
    public var surfaceElevated: Color

    /// Primary text.
    public var textPrimary: Color

    /// Secondary, de-emphasized text.
    public var textSecondary: Color

    /// The brand/action color.
    public var accent: Color

    /// Positive outcomes.
    public var success: Color

    /// Cautionary states.
    public var warning: Color

    /// Errors and destructive actions.
    public var danger: Color

    /// Hairline dividers and card borders.
    public var separator: Color

    /// Creates a color set.
    public init(
        background: Color,
        surface: Color,
        surfaceElevated: Color? = nil,
        textPrimary: Color,
        textSecondary: Color,
        accent: Color,
        success: Color,
        warning: Color,
        danger: Color,
        separator: Color = Color.gray.opacity(0.25)
    ) {
        self.background = background
        self.surface = surface
        self.surfaceElevated = surfaceElevated ?? surface
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.success = success
        self.warning = warning
        self.danger = danger
        self.separator = separator
    }

    /// The pre-`v1.4.0` initializer, kept verbatim — the API contract is
    /// additive-only, and inserting `surfaceElevated:` into this signature
    /// would remove it. Exact-match overload resolution keeps old call sites
    /// binding here; `surfaceElevated` defaults to `surface`.
    public init(
        background: Color,
        surface: Color,
        textPrimary: Color,
        textSecondary: Color,
        accent: Color,
        success: Color,
        warning: Color,
        danger: Color,
        separator: Color = Color.gray.opacity(0.25)
    ) {
        self.init(
            background: background,
            surface: surface,
            surfaceElevated: nil,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            accent: accent,
            success: success,
            warning: warning,
            danger: danger,
            separator: separator
        )
    }

    /// System-native colors — adaptive light/dark with zero configuration.
    public static var system: ThemeColors {
        #if canImport(UIKit)
        ThemeColors(
            background: Color(uiColor: .systemBackground),
            surface: Color(uiColor: .secondarySystemBackground),
            textPrimary: .primary,
            textSecondary: .secondary,
            accent: .accentColor,
            success: .green,
            warning: .orange,
            danger: .red,
            separator: Color(uiColor: .separator)
        )
        #else
        ThemeColors(
            background: Color(nsColor: .windowBackgroundColor),
            surface: Color(nsColor: .controlBackgroundColor),
            textPrimary: .primary,
            textSecondary: .secondary,
            accent: .accentColor,
            success: .green,
            warning: .orange,
            danger: .red,
            separator: Color(nsColor: .separatorColor)
        )
        #endif
    }
}
