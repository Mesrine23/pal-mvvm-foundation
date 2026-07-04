import SwiftUI
import PalPresentation

/// The full-screen failure state: renders a `PresentableError`
/// with an optional Retry button (shown only when the error is retryable and a
/// handler is provided). Use for first-load failures; refresh failures with data
/// on screen belong in a banner over the stale content.
public struct ErrorView: View {

    private let error: PresentableError
    private let retry: (@MainActor () -> Void)?

    @Environment(\.theme) private var theme

    /// Creates an error view.
    /// - Parameters:
    ///   - error: The failure to present.
    ///   - retry: Re-runs the failed operation. Defaults to `nil` (no button).
    public init(_ error: PresentableError, retry: (@MainActor () -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: theme.spacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(theme.typography.largeTitle)
                .foregroundStyle(theme.colors.danger)
                .accessibilityHidden(true)
            Text(error.title)
                .textStyle(.title)
                .multilineTextAlignment(.center)
            Text(error.message)
                .textStyle(.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
            if error.isRetryable, let retry {
                Button(String(localized: "common.retry", bundle: .module), action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.colors.accent)
            }
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
