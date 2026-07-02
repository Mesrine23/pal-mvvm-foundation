# PalNotifications

> Push + local notifications behind one facade: permission, local scheduling (fire-now / delayed / calendar), APNs token plumbing, tap-to-route responses, and a foreground presentation policy. Apps ship the notification *values* (content, categories, deep-link keys); Pal ships the machinery. Dependencies: PalCore (+ the system `UserNotifications` framework).

`import PalNotifications`

## What it gives you

- **`NotificationService`** — the facade you create **once** at the composition root (constructor-injected, no singleton). Creating it claims the notification-center delegate seat, so create it before the app finishes launching.
- **`LocalNotification`** — your app's notifications as typed values via static factories (like `AnalyticsEvent`). Initializer: `LocalNotification(id:title:subtitle:body:sound:badge:categoryID:threadID:userInfo:)`.
- **`NotificationTrigger`** — `.immediate` (fire **now** — the client-side notification an app action triggers) · `.after(Duration)` · `.at(DateComponents, repeats:)`.
- **Streams** — `responses` (taps/action buttons → route) and `pushEvents` (APNs token/failure). Every access returns an **independent subscription**; cold-start taps buffer until first observed.
- **Typed permission** — `requestAuthorization(_:)` / `authorizationStatus()` with Pal's own `Sendable` status/options types; you never import `UserNotifications` for the basics.

## Wiring (composition root + a 5-line AppDelegate)

```swift
@MainActor
final class AppContainer {
    let notifications = NotificationService()   // claims the delegate seat at launch
}

// APNs needs UIKit's AppDelegate callbacks — the app keeps a tiny adaptor:
final class AppDelegate: NSObject, UIApplicationDelegate {
    var notifications: NotificationService?

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notifications?.handleDeviceToken(deviceToken)
    }
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        notifications?.handleRegistrationFailure(error)
    }
}

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container = AppContainer()
    init() { appDelegate.notifications = container.notifications }
    var body: some Scene { WindowGroup { RootView(container: container) } }
}
```

## Local notifications (both flavors)

```swift
// Your values — static factories, app-side:
extension LocalNotification {
    static func orderReady(_ order: Order) -> LocalNotification {
        LocalNotification(
            id: "order-ready-\(order.id)",
            title: String(localized: "Your order is ready"),
            body: order.summary,
            userInfo: ["orderID": order.id]      // rides through to the tap response
        )
    }
}

let granted = try await notifications.requestAuthorization()     // [.alert, .badge, .sound]

try await notifications.schedule(.orderReady(order))             // NOW — action-triggered
try await notifications.schedule(.pickupReminder, trigger: .after(.seconds(30 * 60)))
try await notifications.schedule(.dailyDigest, trigger: .at(nineAM, repeats: true))

notifications.cancelPending(ids: ["order-ready-42"])             // same id ⇒ reschedule replaces
```

## Responses → routes (taps, including cold starts)

Observe once at the root; map `userInfo` to a route (carry an **id**, re-fetch in the destination):

```swift
.task {
    for await response in container.notifications.responses {
        coordinator.handleNotification(response)   // e.g. userInfo["orderID"] → push detail
    }
}
```

A tap that **launched** the app is buffered and replayed to the first subscriber — the push-launch flow is just "set the path".

## APNs registration

```swift
notifications.registerForRemoteNotifications()        // outcome arrives on the stream:

for await event in notifications.pushEvents {
    switch event {
    case .registered(let token): api.registerDevice(token.hexString)   // your backend
    case .failed(let message):   logger.error("APNs registration failed: \(message)")
    }
}
```

Provider SDKs (FCM, …) stay **app-side** — forward the token from the same seam, exactly like analytics adapters.

## Foreground policy & categories

```swift
// How notifications show while the app is OPEN (default: banner + sound):
let notifications = NotificationService { delivered in
    delivered.userInfo["silent"] == "1" ? .hidden : .standard
}

// Action buttons (values app-side, registered once at launch):
notifications.setCategories([
    NotificationCategory(id: "order", actions: [
        NotificationAction(id: "reorder", title: String(localized: "Reorder"), options: [.foreground]),
    ]),
])
// A tapped button arrives as NotificationResponse.actionID == .custom("reorder").
```

## Notes

- **Streams are broadcast**: each access to `responses`/`pushEvents` is an independent subscription — observe from several tasks, resubscribe freely. The latest push event replays to late subscribers (the token is state).
- **`userInfo` crosses as `[String: String]`** (strings + stringified numbers) — carry deep-link keys and ids; complex payload processing stays app-side.
- **Simulator**: test push payloads with `xcrun simctl push booted com.your.bundle payload.apns` (grant permission in-app first).
- **Rich push (Notification Service/Content Extensions)** are app **targets** — they can't usefully ship from SPM; add them app-side (guidance only, deliberately outside v1).
- Errors thrown by `schedule`/`requestAuthorization` are system errors — route action failures to `.appAlert` per the ACTION channel.

See also: [PalNavigation](PalNavigation.md) (routing the tap) · [PalAnalytics](PalAnalytics.md) (the same seam philosophy) · [Architecture](../ARCHITECTURE.md)
