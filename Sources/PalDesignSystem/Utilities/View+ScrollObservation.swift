import SwiftUI

private enum ScrollObservationSpace {
    static let name = "PalScrollObservationSpace"
}

struct ScrollContentGeometry: Equatable, Sendable {

    /// The scrolled distance — `0` at rest, growing as content moves up.
    let offset: CGFloat

    /// The full height of the scrollable content.
    let contentHeight: CGFloat
}

private struct ScrollGeometryKey: PreferenceKey {

    static let defaultValue: ScrollContentGeometry? = nil

    static func reduce(value: inout ScrollContentGeometry?, nextValue: () -> ScrollContentGeometry?) {
        value = nextValue() ?? value
    }
}

private struct OnScrollOffsetChangeModifier: ViewModifier {

    let action: @MainActor (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: ScrollObservationSpace.name)
            .onPreferenceChange(ScrollGeometryKey.self) { geometry in
                guard let geometry else { return }
                action(geometry.offset)
            }
    }
}

private struct OnReachedBottomModifier: ViewModifier {

    let threshold: CGFloat
    let action: @MainActor () -> Void

    @State private var viewportHeight: CGFloat = 0
    @State private var isInThresholdZone = false

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: ScrollObservationSpace.name)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { viewportHeight = $0 }
            .onPreferenceChange(ScrollGeometryKey.self) { geometry in
                guard let geometry else { return }
                let distanceToBottom = geometry.contentHeight - (geometry.offset + viewportHeight)
                let isNowInZone = distanceToBottom <= threshold
                guard isNowInZone != isInThresholdZone else { return }
                isInThresholdZone = isNowInZone
                if isNowInZone {
                    action()
                }
            }
    }
}

public extension View {

    /// Marks this view — the direct content of a `ScrollView` — as the target the
    /// scroll-observation modifiers measure. Pair it with ``onScrollOffsetChange(perform:)``
    /// or ``onReachedBottom(threshold:perform:)`` applied to the `ScrollView` itself.
    func scrollObservationTarget() -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollGeometryKey.self,
                    value: ScrollContentGeometry(
                        offset: -geometry.frame(in: .named(ScrollObservationSpace.name)).minY,
                        contentHeight: geometry.size.height
                    )
                )
            }
        )
    }

    /// Observes the scroll offset (`0` at rest, growing as content scrolls up) —
    /// for offset-driven effects such as collapsing headers or a scroll-to-top button.
    ///
    /// Apply to the `ScrollView`; mark its content with ``scrollObservationTarget()``:
    ///
    /// ```swift
    /// ScrollView {
    ///     content.scrollObservationTarget()
    /// }
    /// .onScrollOffsetChange { offset in headerCollapsed = offset > 100 }
    /// ```
    ///
    /// On an iOS 18+ floor, prefer the native `onScrollGeometryChange` — this is
    /// the iOS 17-compatible equivalent.
    func onScrollOffsetChange(perform action: @escaping @MainActor (CGFloat) -> Void) -> some View {
        modifier(OnScrollOffsetChangeModifier(action: action))
    }

    /// Runs `action` when the content's bottom edge enters the threshold zone —
    /// once per entry, re-arming after the zone is left. Also fires when the
    /// content is shorter than the viewport (the bottom is already visible).
    ///
    /// Apply to the `ScrollView`; mark its content with ``scrollObservationTarget()``.
    /// For `List`/lazy stacks — where content views materialize on scroll — trigger
    /// work from the appearance of a trailing row instead (see the pagination
    /// pattern in PalPresentation).
    func onReachedBottom(threshold: CGFloat = 200, perform action: @escaping @MainActor () -> Void) -> some View {
        modifier(OnReachedBottomModifier(threshold: threshold, action: action))
    }
}
