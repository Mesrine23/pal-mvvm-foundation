import Observation
import PalPresentation
import WebKit

/// The observable state of one web screen — own it in the presenting view (or
/// ViewModel), hand it to ``WebScreen``, and switch on ``state`` exactly like
/// any other loaded content (Pal ships no `StateView`; the screen composes its
/// own loading/error affordances around the web view).
///
/// ```swift
/// @State private var page = WebPageModel()
///
/// WebScreen(url: termsURL, page: page)
///     .overlay {
///         if let error = page.state.error {
///             ErrorView(error) { page.reload() }
///         }
///     }
/// ```
@MainActor @Observable
public final class WebPageModel {

    /// The page's load state — `loading` from navigation start, `loaded` on
    /// finish, `failed` with a ``PresentableError`` on error (cancelled
    /// navigations never surface, per the foundation's cancellation rule).
    public private(set) var state: ViewState<Void> = .idle

    /// The document title, live as the page updates it.
    public private(set) var title: String?

    /// The estimated load progress (`0…1`), for a progress bar.
    public private(set) var progress: Double = 0

    /// Whether back navigation is possible.
    public private(set) var canGoBack = false

    /// Whether forward navigation is possible.
    public private(set) var canGoForward = false

    @ObservationIgnored private weak var webView: WKWebView?

    /// Creates an idle page model.
    public init() {}

    /// Reloads the current page (also the retry for a failed load).
    public func reload() {
        webView?.reload()
    }

    /// Navigates back in the page's history.
    public func goBack() {
        webView?.goBack()
    }

    /// Navigates forward in the page's history.
    public func goForward() {
        webView?.goForward()
    }

    func bind(_ webView: WKWebView) {
        self.webView = webView
    }

    func beginNavigation() {
        state = .loading(previous: state.value)
    }

    func finishNavigation() {
        state = .loaded(())
    }

    func failNavigation(_ error: any Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        state = .failed(PresentableError(from: error), previous: state.value)
    }

    func update(title: String?) {
        self.title = title
    }

    func update(progress: Double) {
        self.progress = progress
    }

    func update(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
}
