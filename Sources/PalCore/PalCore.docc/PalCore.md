# ``PalCore``

The Foundation-only bedrock every other product builds on — logging, curated extensions, async utilities, and app metadata. No SwiftUI, so Domain code can depend on it safely.

## Overview

`PalCore` deliberately ships only app-agnostic mechanisms. Validation rules, user-facing strings, and other app values never live here. The curated `Foundation` extensions (`String.trimmed`, `Collection[safe:]`, `Date(iso8601:)`, …) appear under their extended types in this reference.

For the narrative guide, see the repository's `Documentation/Products/PalCore.md`.

## Topics

### Logging

- ``LoggerFactory``

### Async utilities

- ``Debouncer``
- ``withTimeout(_:operation:)``
- ``TimeoutError``

### App metadata

- ``AppInfo``
- ``AppLanguage``
