# ``PalAuth``

Token-storage glue (Keychain ⇄ Networking) plus biometric gating behind one typed call.

## Overview

``KeychainTokenStore`` exists so PalNetworking stays storage-agnostic and PalPersistence stays auth-agnostic. ``BiometricAuthenticator`` wraps `LocalAuthentication` with a fresh context per evaluation; cancellation and the fallback button are **outcomes**, never errors.

For the narrative guide, see the repository's `Documentation/Products/PalAuth.md`.

## Topics

### Token storage

- ``KeychainTokenStore``

### Biometrics

- ``BiometricAuthenticator``
- ``BiometryKind``
- ``BiometricOutcome``
- ``BiometricError``
