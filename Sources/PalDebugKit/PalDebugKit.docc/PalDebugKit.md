# ``PalDebugKit``

A shake-to-debug suite — network logs, environment switching, and response mocking — in an overlay above any app state.

## Overview

Activation is runtime and default-OFF: nothing happens until the app calls ``PalDebugTools/enable(environments:for:)`` behind its own `DEBUGKIT` compilation flag. The base URL resolves per request through ``EnvironmentResolver`` (backing `HTTPClient`'s `baseURLProvider`), and every environment switch broadcasts on ``PalDebugTools/environmentChanges`` so the app runs its own reset.

For the narrative guide — including the triple-fence gating recipe — see the repository's `Documentation/Products/PalDebugKit.md`.

## Topics

### Entry point

- ``PalDebugTools``

### Environments

- ``APIEnvironment``
- ``ClientID``
- ``EnvironmentChanged``
- ``EnvironmentResolver``
