# ``PalNotifications``

Push + local notifications behind one facade: permission, scheduling, APNs token plumbing, tap-to-route responses, and a foreground presentation policy.

## Overview

Create one ``NotificationService`` at the composition root **before the app finishes launching** — creation claims the notification-center delegate seat, so cold-start taps are captured (they buffer until ``NotificationService/responses`` is first observed). Apps declare their notifications as static factories on ``LocalNotification``; provider SDKs stay app-side.

For the narrative guide — including the 5-line `UIApplicationDelegateAdaptor` — see the repository's `Documentation/Products/PalNotifications.md`.

## Topics

### The facade

- ``NotificationService``

### Local notifications

- ``LocalNotification``
- ``NotificationTrigger``
- ``NotificationSound``

### Permission

- ``NotificationAuthorizationStatus``
- ``NotificationOptions``

### Responses & foreground delivery

- ``NotificationResponse``
- ``DeliveredNotification``
- ``NotificationPresentation``

### Push registration

- ``PushToken``
- ``PushRegistrationEvent``

### Categories

- ``NotificationCategory``
- ``NotificationAction``
