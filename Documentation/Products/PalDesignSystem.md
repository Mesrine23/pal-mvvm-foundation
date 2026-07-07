# PalDesignSystem

> Opt-in theming plus the SwiftUI building blocks that render `ViewState`/`PresentableError` and host alerts — themed by tokens, never by hardcoded values. Dependencies: PalCore, PalPresentation.

`import PalDesignSystem`

## What it gives you

- **`Theme`** — a deliberate **minimal bridge**: semantic colors, typography, spacing, radii, shadows. Opt-in via `@Environment(\.theme)`, defaulting to `Theme.system` (works with zero setup).
- **`.textStyle(_:)`** — apply a `TextStyleToken` from the theme (sugar, never a gate; raw SwiftUI styling always available).
- **State components** — `ErrorView`, `SectionErrorView`, `EmptyStateView`, `LoadingView`.
- **`.appAlert(...)`** — themed alert chrome driven by an `AppAlert` value (+ a custom-content overload).
- **`.appToast(...)`** — transient, non-blocking confirmations driven by an `AppToast` value (auto-dismiss, swipe to dismiss).
- **Skeleton loading** — `.skeleton(when:)` and `.shimmering(active:)` for the first-load placeholder state.
- **Scroll observation** — `.onScrollOffsetChange(perform:)` and `.onReachedBottom(threshold:perform:)` over a `.scrollObservationTarget()` content marker.
- **Utilities** — `hideKeyboard()`, `onFirstAppear { }`, `.shadow(_ token:)`.

Localized en + el; components accept optional custom strings.

## Theming

`Theme` carries only the slots Pal's own components need. Apps with a rich design system keep their full token layer and map a subset in.

```swift
import PalDesignSystem

// Use system defaults everywhere — no setup. Or brand in one line at the root:
ContentView().theme(myBrandTheme)

// Build a theme from the system baseline, overriding what you need:
var theme = Theme.system
theme.colors.accent = .pink
```

Slots: `colors` (`background`, `surface`, `surfaceElevated`, `textPrimary`, `textSecondary`, `accent`, `success`, `warning`, `danger`, `separator`), `typography` (`largeTitle`/`title`/`headline`/`body`/`caption`), `spacing` (`xs…xl`), `radii` (`s`/`m`/`l`), `shadows` (`level1`/`level2`).

`surfaceElevated` is the tone for floating chrome (sheets, alerts, toasts) one level above `surface`; it **defaults to `surface`**, so themes that don't distinguish the two change nothing. Design-tool hex values map directly: `Color(hex: 0xF3F1EC)` (compile-checked) or `Color(hex: "#F3F1EC")` (failable, accepts `#RRGGBB`/`#RRGGBBAA`).

## Text styles

```swift
Text("Welcome").textStyle(.largeTitle)     // built-in tokens: .largeTitle/.title/.headline/.body/.caption
```

`TextStyleToken` carries font + optional color + optional `tracking` / `lineSpacing`. Add your own:

```swift
extension TextStyleToken {
    static let price = TextStyleToken(font: { $0.typography.title }, color: { $0.colors.accent })
}
```

Apply `.textStyle` **last** (it returns `some View`, not `Text`). And note: **every file using `.textStyle` must `import PalDesignSystem` itself** — it's an extension, and importing another Pal product is not enough (the compiler error says "not available due to missing import").

## State components

```swift
ErrorView(error) { viewModel.refresh() }       // full-screen PresentableError + Retry
SectionErrorView(error) { viewModel.reload() } // inline per-topic failure
EmptyStateView(
    systemImage: "person.slash",
    title: String(localized: "No users"),
    message: String(localized: "Nothing to show yet."),   // optional
    actionTitle: String(localized: "Reload"),             // optional
    action: { viewModel.reload() }                        // optional
)
LoadingView(message: "Loading…")
```

These render the `ViewState` cases (see [PalPresentation](PalPresentation.md)); accessibility labels on actions are built in.

For wrapping chip/tag rows there's **`FlowLayout`** — a `Layout` that flows subviews left-to-right and breaks rows when the width runs out:

```swift
FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
    ForEach(tags) { TagChip($0) }
}
```

## Skeletons & shimmer

The modern first-load affordance: render your **real layout with placeholder values**, redacted into shapes with a highlight sweeping across — instead of (or alongside) a spinner.

```swift
switch viewModel.users.state {
case .idle, .loading(previous: nil):  list(User.placeholders).skeleton(when: true)
case .loading(previous: let cached?): list(cached)          // refresh keeps real content
case .loaded(let users):              list(users)
// …
}

extension User {   // app-side placeholder values — masked, never rendered; length sizes the bars
    static let placeholders: [User] = (1...8).map { User(id: -$0, name: "Placeholder Person Name", …) }
}
```

- **`.skeleton(when:)`** = `.redacted(reason: .placeholder)` + shimmer + interaction disabled, in one modifier. Reusing your real row view keeps the skeleton pixel-accurate for free.
- **`.shimmering(active:)`** is the sweep alone — usable on any custom placeholder (works by masking, so it needs no color configuration and sits correctly on any background).
- `LoadingView` remains the right choice where a layout has no meaningful shape to preview (full-screen waits, submissions).

## Scroll observation

Geometry utilities for plain `ScrollView` compositions — offset-driven effects (collapsing headers, a scroll-to-top button) and bottom-proximity work:

```swift
ScrollView {
    content
        .scrollObservationTarget()            // marks the measured content
}
.onScrollOffsetChange { offset in isHeaderCollapsed = offset > 100 }
.onReachedBottom(threshold: 200) { /* bottom entered the zone (fires once per entry) */ }
```

- The pair is deliberate: the **target** marks the content being measured; the observers sit on the `ScrollView`. `onReachedBottom` re-arms when the bottom leaves the zone, and also fires when content is shorter than the viewport.
- **In `List` and lazy stacks**, rows materialize on scroll — trigger work from the appearance of a trailing row instead of measuring geometry (that is also the canonical pagination trigger; see [PalPresentation](PalPresentation.md)).
- On an iOS 18+ floor the native `onScrollGeometryChange` supersedes `onScrollOffsetChange`; these are the iOS 17-compatible equivalents.

## Alerts (action-failure channel)

```swift
// AppAlert { kind: .info/.success/.warning/.error, title, message, primary, secondary? }
@State private var alert: AppAlert?

someView
    .appAlert($alert)

// Built-in error bridge + app-defined factories:
alert = .error(presentableError)
```

Declare case-specific alerts as static factories on `AppAlert`. For bespoke content, use the overload `.appAlert($item) { item in CustomContent(item) }` — the foundation owns the chrome (dim, card, animation, dismiss).

**The ViewModel owns the alert/toast state** (`var alert: AppAlert?`), and importing PalDesignSystem for that is the blessed shape — layer rule 10 sanctions it explicitly. The purist alternative (VM exposes `PresentableError?`, the View maps it) remains valid but is not required.

**Known limitation:** a root-level overlay does not render above an active `.sheet` — apply `.appAlert` per presentation context.

## Toasts (non-blocking confirmations)

The other half of the ACTION channel: `.appAlert` interrupts for failures that need acknowledgement; a **toast** confirms without stealing focus — "Saved", "Scheduled", "Copied".

```swift
@State private var toast: AppToast?

someView
    .appToast($toast)

// AppToast { kind: .info/.success/.warning/.error, title, message?, duration (default 3 s) }
toast = AppToast(kind: .success, title: String(localized: "Saved"))
```

- Auto-dismisses after `duration`; swipe down (or the accessibility "Dismiss" action) dismisses early; presenting a new value replaces the current one.
- Themed by tokens (surface card, semantic tint per `kind`, elevation shadow) — no configuration needed.
- Declare app toasts as static factories on `AppToast`, like alerts.
- Same placement caveat as `.appAlert`: apply per presentation context — a root-level overlay does not render above an active `.sheet`.

## Notes

- `Theme` is intentionally minimal — it is a bridge, not a full design system. No `StateView` (screens keep the explicit `ViewState` switch).
- No magic numbers in UI — use theme tokens for spacing/radii (clean-code rule 7).
- Generic SwiftUI helpers live here (not in Core, which is SwiftUI-free).

See also: [PalPresentation](PalPresentation.md) · [Architecture](../ARCHITECTURE.md)
