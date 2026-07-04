# ``PalPersistence``

Type-safe storage: Keychain, UserDefaults, and an in-memory TTL cache — all driven by typed keys with uniform `get` / `set` / `delete` verbs.

## Overview

Apps declare their own keys as static extensions on ``KeychainKey``, ``DefaultsKey``, and ``CacheKey`` — no app keys ship in the foundation. ``MemoryCache`` is memory-only by policy (passive TTL, nothing survives a launch); local *relational* stores (SwiftData/Core Data) stay app-side behind repositories.

For the narrative guide, see the repository's `Documentation/Products/PalPersistence.md`.

## Topics

### Keychain

- ``KeychainService``
- ``KeychainStorage``
- ``KeychainKey``
- ``KeychainAccessibility``
- ``KeychainError``

### UserDefaults

- ``UserDefaultsService``
- ``DefaultsStorage``
- ``DefaultsKey``

### In-memory cache

- ``MemoryCache``
- ``CacheKey``
