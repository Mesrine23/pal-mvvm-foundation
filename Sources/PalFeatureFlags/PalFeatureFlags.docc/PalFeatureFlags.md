# ``PalFeatureFlags``

A simple, synchronous feature-flag seam: typed flags with safe defaults, read from memory.

## Overview

Fetch remote configuration once at launch, seed ``InMemoryFeatureFlagsProvider``, and read synchronously everywhere — no `async` at call sites. Apps declare flags as static factories on ``FeatureFlag``; a missing value degrades to the flag's `defaultValue`.

For the narrative guide, see the repository's `Documentation/Products/PalFeatureFlags.md`.

## Topics

### The seam

- ``FeatureFlagsProvider``
- ``FeatureFlag``

### Shipped implementations

- ``InMemoryFeatureFlagsProvider``
- ``NoOpFeatureFlagsProvider``
