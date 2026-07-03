#if canImport(UIKit)
import SwiftUI
import UIKit
import WebKit

/// An embedded web page: a `WKWebView` whose loading drives a ``WebPageModel``'s
/// `ViewState`, with every navigation routed through the app's
/// ``WebNavigationPolicy`` (allow · cancel · open externally).
///
/// Named `WebScreen` deliberately — iOS 26's SwiftUI ships a native `WebView`,
/// and this avoids colliding with it on newer floors.
///
/// OAuth note: sign-in flows do NOT belong in an embedded web view — use
/// `ASWebAuthenticationSession` app-side (RFC 8252); this screen is for content
/// (terms, help, embedded pages).
@available(iOSApplicationExtension, unavailable)
public struct WebScreen: UIViewRepresentable {

    private let url: URL
    private let page: WebPageModel?
    private let headers: [String: String]
    private let policy: WebNavigationPolicy

    /// Creates a web screen.
    /// - Parameters:
    ///   - url: The initial page.
    ///   - page: The observable model to drive (state/title/progress/history). Optional.
    ///   - headers: Extra header fields for the **initial** request only.
    ///   - policy: Decides each navigation. Defaults to allowing everything.
    public init(
        url: URL,
        page: WebPageModel? = nil,
        headers: [String: String] = [:],
        policy: @escaping WebNavigationPolicy = { _ in .allow }
    ) {
        self.url = url
        self.page = page
        self.headers = headers
        self.policy = policy
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(page: page, policy: policy)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.bind(webView)
        page?.bind(webView)

        var request = URLRequest(url: url)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        webView.load(request)
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {}

    /// Bridges `WKNavigationDelegate` into the model transitions and the policy seam.
    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate {

        private let page: WebPageModel?
        private let policy: WebNavigationPolicy
        private var observations: [NSKeyValueObservation] = []

        init(page: WebPageModel?, policy: @escaping WebNavigationPolicy) {
            self.page = page
            self.policy = policy
        }

        func bind(_ webView: WKWebView) {
            guard let page else { return }
            // WKWebView posts these KVO changes on the main thread; the handler
            // closure is not MainActor-annotated by the SDK, so we assert it.
            observations = [
                webView.observe(\.estimatedProgress, options: [.new]) { [weak page] webView, _ in
                    MainActor.assumeIsolated {
                        page?.update(progress: webView.estimatedProgress)
                    }
                },
                webView.observe(\.title, options: [.new]) { [weak page] webView, _ in
                    MainActor.assumeIsolated {
                        page?.update(title: webView.title)
                    }
                },
                webView.observe(\.canGoBack, options: [.new]) { [weak page] webView, _ in
                    MainActor.assumeIsolated {
                        page?.update(canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
                    }
                },
                webView.observe(\.canGoForward, options: [.new]) { [weak page] webView, _ in
                    MainActor.assumeIsolated {
                        page?.update(canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
                    }
                },
            ]
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            page?.beginNavigation()
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            page?.finishNavigation()
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            page?.failNavigation(error)
        }

        public func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: any Error
        ) {
            page?.failNavigation(error)
        }

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let request = WebNavigationRequest(
                url: url,
                isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true
            )
            switch policy(request) {
            case .allow:
                decisionHandler(.allow)
            case .cancel:
                decisionHandler(.cancel)
            case .openExternally:
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}
#endif
