# ``PalDesignSystem``

Opt-in theming plus the SwiftUI building blocks that render the foundation's states — themed by tokens, never by hardcoded values.

## Overview

``Theme`` is a deliberate minimal bridge: apps with a rich design system keep their own token layer and map a subset in. The state components render `ViewState` cases; the ACTION channel splits into interrupting alerts (``AppAlert``) and non-blocking confirmations (``AppToast``). View-modifier utilities (`.textStyle`, `.skeleton`, `.shimmering`, `.appAlert`, `.appToast`, scroll observation, `hideKeyboard`, `onFirstAppear`) appear under SwiftUI's `View` in this reference.

For the narrative guide, see the repository's `Documentation/Products/PalDesignSystem.md`.

## Topics

### Theming

- ``Theme``
- ``ThemeColors``
- ``ThemeTypography``
- ``ThemeSpacing``
- ``ThemeRadii``
- ``ThemeShadows``
- ``ThemeShadow``
- ``TextStyleToken``

### State components

- ``LoadingView``
- ``ErrorView``
- ``SectionErrorView``
- ``EmptyStateView``

### Alerts & toasts (the ACTION channel)

- ``AppAlert``
- ``AlertAction``
- ``AppToast``
