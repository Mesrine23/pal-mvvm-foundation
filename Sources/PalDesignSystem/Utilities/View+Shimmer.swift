import SwiftUI

private struct ShimmerModifier: ViewModifier {

    let active: Bool

    @State private var phase = Self.sweepStart

    private static let sweepStart: CGFloat = -0.35
    private static let sweepEnd: CGFloat = 1.35
    private static let bandRadius: CGFloat = 0.25
    private static let dimmedOpacity: Double = 0.45
    private static let period: TimeInterval = 1.3

    func body(content: Content) -> some View {
        if active {
            content
                .mask(sweep)
                .task {
                    phase = Self.sweepStart
                    withAnimation(.linear(duration: Self.period).repeatForever(autoreverses: false)) {
                        phase = Self.sweepEnd
                    }
                }
        } else {
            content
        }
    }

    private var sweep: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(Self.dimmedOpacity), location: phase - Self.bandRadius),
                .init(color: .black, location: phase),
                .init(color: .black.opacity(Self.dimmedOpacity), location: phase + Self.bandRadius),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

public extension View {

    /// Sweeps an animated highlight band across the view while `active` — the
    /// loading affordance for placeholder content. Works on any view; pair with
    /// `.redacted(reason: .placeholder)` or use ``skeleton(when:)`` directly.
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }

    /// A skeleton loading state: redacts content into placeholder shapes,
    /// shimmers across them, and disables interaction while `active`.
    ///
    /// Render **representative placeholder values** so the shapes match the
    /// loaded layout — the text is masked, never shown, so its length only
    /// sizes the shapes. The canonical pairing is the first load:
    ///
    /// ```swift
    /// case .idle, .loading(previous: nil): list(User.placeholders).skeleton(when: true)
    /// case .loading(previous: let cached?): list(cached)   // refresh keeps real content
    /// ```
    func skeleton(when active: Bool) -> some View {
        redacted(reason: active ? .placeholder : [])
            .shimmering(active: active)
            .allowsHitTesting(!active)
    }
}
