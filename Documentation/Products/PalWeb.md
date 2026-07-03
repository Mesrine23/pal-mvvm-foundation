# PalWeb

> Embedded web content for **pages** (terms, help, docs) — a `WKWebView` screen whose loading drives the familiar `ViewState`, with every navigation routed through an app-supplied policy — plus an external-browser opener for non-View contexts. Dependencies: PalCore, PalPresentation (+ the system `WebKit` framework); the UI is `#if canImport(UIKit)`-gated.

`import PalWeb`

## What it gives you

- **`WebScreen`** — the `WKWebView` representable: back/forward gestures, initial-request `headers`, and the navigation-policy seam. (Named `WebScreen` deliberately — iOS 26's SwiftUI ships a native `WebView`.)
- **`WebPageModel`** — `@MainActor @Observable`: `state: ViewState<Void>`, live `title` / `progress` / `canGoBack` / `canGoForward`, and `reload()` / `goBack()` / `goForward()`.
- **`WebNavigationPolicy`** — `(WebNavigationRequest) -> .allow / .cancel / .openExternally`: your app decides which hosts stay in; `.openExternally` cancels in-view and hands the URL to the system browser.
- **`ExternalLinkOpener`** — opens a URL in the external browser from ViewModels/coordinators (in Views, prefer the environment's `openURL`).

## Usage

Pal ships no `StateView` for web either — compose your own loading/error affordances around the screen, switching on the model exactly like any loaded content:

```swift
struct AboutView: View {
    @State private var page = WebPageModel()

    var body: some View {
        WebScreen(
            url: aboutURL,
            page: page,
            policy: { request in
                request.url.host()?.hasSuffix("example.com") == true ? .allow : .openExternally
            }
        )
        .overlay {
            if let error = page.state.error {
                ErrorView(error) { page.reload() }
            } else if page.state.isLoading, page.state.value == nil {
                LoadingView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if page.state.isLoading {
                ProgressView(value: page.progress).progressViewStyle(.linear)
            }
        }
        .navigationTitle(page.title ?? String(localized: "About"))
    }
}
```

```swift
// From a ViewModel or coordinator (non-View context):
ExternalLinkOpener().open(supportURL)
```

## Notes

- **OAuth does NOT belong here.** Sign-in flows use `ASWebAuthenticationSession` app-side (RFC 8252) — an embedded web view is the wrong tool for credentials.
- Cancelled navigations (`NSURLErrorCancelled`) never surface as failures.
- `headers` apply to the **initial** request only; cookie management is deliberately not wrapped (additive later if dogfooding demands it).
- `WebScreen`/`ExternalLinkOpener` are unavailable in app extensions (they need `UIApplication`).
- JS message bridge: deferred, additive later.

See also: [PalPresentation](PalPresentation.md) (`ViewState`) · [Architecture](../ARCHITECTURE.md)
