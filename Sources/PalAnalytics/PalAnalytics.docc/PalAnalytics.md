# ``PalAnalytics``

A provider-agnostic analytics seam: ViewModels track through one protocol, SDK adapters stay at the app's composition root.

## Overview

Apps define events as static factories on ``AnalyticsEvent`` — the foundation ships no event names. Register ``NoOpAnalyticsTracker`` by default and swap in real adapters (conforming to ``AnalyticsTracker``) in one line.

For the narrative guide, see the repository's `Documentation/Products/PalAnalytics.md`.

## Topics

### The seam

- ``AnalyticsTracker``
- ``AnalyticsEvent``
- ``AnalyticsValue``

### Shipped implementations

- ``NoOpAnalyticsTracker``
- ``ConsoleAnalyticsTracker``
- ``CompositeAnalyticsTracker``
