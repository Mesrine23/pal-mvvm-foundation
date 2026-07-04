# ``PalNavigation``

Typed, payload-carrying routes over `NavigationStack`, a router coordinators own, nested-stack modals, and deep links. Zero `AnyView`.

## Overview

Apps define a route enum conforming to ``Routable``; a coordinator owns the ``Router`` and implements the screens' navigation delegates as one-liners; ``RouterView`` renders the stack and modal bindings (presentations are `Identifiable` items, never booleans).

For the narrative guide — including the coordinator triangle — see the repository's `Documentation/Products/PalNavigation.md`.

## Topics

### Routes & router

- ``Routable``
- ``Router``
- ``RouterView``

### Modals

- ``PresentedModal``
- ``ModalStyle``

### Deep links

- ``DeepLinkHandler``
- ``DeepLinkResult``
- ``NavigationStrategy``
