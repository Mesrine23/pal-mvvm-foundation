# ``PalNetworking``

A typed request/response client with an interceptor pipeline, single-flight auth refresh, and network-condition observation.

## Overview

Apps define endpoints as one-line static factories returning ``Request`` values in their Data layer; ``HTTPClient`` sends them with typed `throws(NetworkError)`. Cross-cutting behavior composes as an interceptor onion over ``TransportRequest`` (canonical order: inspector → mock → logging → retry → auth → transport).

For the narrative guide, see the repository's `Documentation/Products/PalNetworking.md`.

## Topics

### Requests

- ``Request``
- ``HTTPMethod``
- ``HTTPBody``
- ``MultipartPart``
- ``RequestOptions``
- ``RedirectPolicy``
- ``EmptyResponse``

### Client

- ``NetworkClient``
- ``HTTPClient``
- ``NetworkResponse``
- ``NetworkError``

### Interceptors

- ``Interceptor``
- ``Next``
- ``TransportRequest``
- ``LoggingInterceptor``
- ``RetryInterceptor``
- ``AuthInterceptor``

### Auth refresh

- ``TokenProvider``
- ``TokenStore``
- ``TokenRefreshService``
- ``AuthTokens``
- ``AuthEvent``
- ``AuthError``

### Reachability

- ``ReachabilityMonitor``
- ``NetworkStatus``
