# PalDesignSystem

> Opt-in theming plus the SwiftUI building blocks that render `ViewState`/`PresentableError` and host alerts — themed by tokens, never by hardcoded values. Dependencies: PalCore, PalPresentation.

`import PalDesignSystem`

## What it gives you

- **`Theme`** — a deliberate **minimal bridge**: semantic colors, typography, spacing, radii, shadows. Opt-in via `@Environment(\.theme)`, defaulting to `Theme.system` (works with zero setup).
- **`.textStyle(_:)`** — apply a `TextStyleToken` from the theme (sugar, never a gate; raw SwiftUI styling always available).
- **State components** — `ErrorView`, `SectionErrorView`, `EmptyStateView`, `LoadingView`.
- **`.appAlert(...)`** — themed alert chrome driven by an `AppAlert` value (+ a custom-content overload).
- **Skeleton loading** — `.skeleton(when:)` and `.shimmering(active:)` for the first-load placeholder state.
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

Slots: `colors` (`background`, `surface`, `textPrimary`, `textSecondary`, `accent`, `success`, `warning`, `danger`, `separator`), `typography` (`largeTitle`/`title`/`headline`/`body`/`caption`), `spacing` (`xs…xl`), `radii` (`s`/`m`/`l`), `shadows` (`level1`/`level2`).

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

Apply `.textStyle` **last** (it returns `some View`, not `Text`).

## State components

```swift
ErrorView(error) { viewModel.refresh() }       // full-screen PresentableError + Retry
SectionErrorView(error) { viewModel.reload() } // inline per-topic failure
EmptyStateView(/* icon/title/message/action */)
LoadingView(message: "Loading…")
```

These render the `ViewState` cases (see [PalPresentation](PalPresentation.md)); accessibility labels on actions are built in.

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

**Known limitation:** a root-level overlay does not render above an active `.sheet` — apply `.appAlert` per presentation context.

## Notes

- `Theme` is intentionally minimal — it is a bridge, not a full design system. No `StateView` (screens keep the explicit `ViewState` switch).
- No magic numbers in UI — use theme tokens for spacing/radii (clean-code rule 7).
- Generic SwiftUI helpers live here (not in Core, which is SwiftUI-free).

See also: [PalPresentation](PalPresentation.md) · [Architecture](../ARCHITECTURE.md)
