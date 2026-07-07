import SwiftUI

/// Known limitation (by canon): an overlay does not render above an active
/// `.sheet` — apply `.appAlert` inside each presentation context that needs it.
public extension View {

    /// Presents the standard themed popup while the binding holds an alert.
    func appAlert(_ alert: Binding<AppAlert?>) -> some View {
        appAlert(item: alert) { value in
            DefaultAlertCard(alert: value, dismiss: { alert.wrappedValue = nil })
        }
    }

    /// Presents fully custom content inside the same chrome (dimmed backdrop,
    /// surface card, animation, tap-outside dismissal).
    func appAlert<Item: Identifiable, AlertContent: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> AlertContent
    ) -> some View {
        modifier(AppAlertChromeModifier(item: item, alertContent: content))
    }
}

private struct AppAlertChromeModifier<Item: Identifiable, AlertContent: View>: ViewModifier {

    @Binding var item: Item?
    let alertContent: (Item) -> AlertContent

    @Environment(\.theme) private var theme

    private static var dimOpacity: Double { 0.4 }
    private static var cardMaxWidth: CGFloat { 320 }

    func body(content: Content) -> some View {
        content.overlay {
            if let item {
                ZStack {
                    Color.black.opacity(Self.dimOpacity)
                        .ignoresSafeArea()
                        .onTapGesture { self.item = nil }
                    alertContent(item)
                        .padding(theme.spacing.l)
                        .frame(maxWidth: Self.cardMaxWidth)
                        .background(theme.colors.surfaceElevated, in: RoundedRectangle(cornerRadius: theme.radii.l))
                        .padding(theme.spacing.l)
                        .accessibilityAddTraits(.isModal)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: item?.id)
    }
}

struct DefaultAlertCard: View {

    let alert: AppAlert
    let dismiss: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.m) {
            Image(systemName: iconName)
                .font(theme.typography.largeTitle)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            Text(alert.title)
                .textStyle(.title)
                .multilineTextAlignment(.center)
            Text(alert.message)
                .textStyle(.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
            actions
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let secondary = alert.secondary {
            HStack(spacing: theme.spacing.s) {
                actionButton(secondary)
                actionButton(alert.primary)
            }
        } else {
            actionButton(alert.primary)
        }
    }

    private func actionButton(_ action: AlertAction) -> some View {
        Button(action.title) {
            action.action()
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .tint(tint(for: action.role))
    }

    private func tint(for role: AlertAction.Role) -> Color {
        switch role {
        case .standard: theme.colors.accent
        case .destructive: theme.colors.danger
        case .cancel: theme.colors.textSecondary
        }
    }

    private var iconName: String {
        switch alert.kind {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    private var iconColor: Color {
        switch alert.kind {
        case .info: theme.colors.accent
        case .success: theme.colors.success
        case .warning: theme.colors.warning
        case .error: theme.colors.danger
        }
    }
}
