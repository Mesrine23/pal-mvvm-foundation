import SwiftUI

private struct AppToastModifier: ViewModifier {

    @Binding var toast: AppToast?

    private static let animationDuration: TimeInterval = 0.3

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast {
                    ToastCard(toast: toast) { self.toast = nil }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast.id) {
                            try? await Task.sleep(for: toast.duration)
                            guard !Task.isCancelled else { return }
                            self.toast = nil
                        }
                }
            }
            .animation(.spring(duration: Self.animationDuration), value: toast?.id)
    }
}

private struct ToastCard: View {

    let toast: AppToast
    let dismiss: () -> Void

    @Environment(\.theme) private var theme

    private static let swipeDistance: CGFloat = 12

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(toast.title).textStyle(.headline)
                if let message = toast.message {
                    Text(message).textStyle(.caption)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(theme.spacing.m)
        .background(theme.colors.surfaceElevated, in: RoundedRectangle(cornerRadius: theme.radii.m))
        .shadow(theme.shadows.level2)
        .padding(.horizontal, theme.spacing.m)
        .padding(.bottom, theme.spacing.s)
        .gesture(
            DragGesture(minimumDistance: Self.swipeDistance).onEnded { value in
                if value.translation.height > 0 {
                    dismiss()
                }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("common.dismiss", bundle: .module)) { dismiss() }
    }

    private var iconName: String {
        switch toast.kind {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch toast.kind {
        case .info: theme.colors.accent
        case .success: theme.colors.success
        case .warning: theme.colors.warning
        case .error: theme.colors.danger
        }
    }
}

public extension View {

    /// Presents a transient toast bound to an optional ``AppToast`` — auto-dismisses
    /// after its `duration`, swipe-down (or the accessibility action) dismisses
    /// early, and presenting a new value replaces the current one.
    ///
    /// The non-blocking CONFIRMATION side of the ACTION channel — failures that
    /// need acknowledgement go through `.appAlert` instead.
    ///
    /// Like `.appAlert`, a root-level overlay does not render above an active
    /// `.sheet` — apply per presentation context.
    func appToast(_ toast: Binding<AppToast?>) -> some View {
        modifier(AppToastModifier(toast: toast))
    }
}
