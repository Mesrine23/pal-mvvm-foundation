import Foundation

/// One attempted navigation, as handed to the app's ``WebNavigationPolicy``.
public struct WebNavigationRequest: Sendable, Equatable {

    /// The destination.
    public let url: URL

    /// Whether the navigation targets the main frame (`false` for iframes).
    public let isMainFrame: Bool

    /// Creates a navigation request.
    public init(url: URL, isMainFrame: Bool) {
        self.url = url
        self.isMainFrame = isMainFrame
    }
}

/// The app-supplied seam deciding each navigation — the app ships the policy
/// (which hosts stay in, what leaves to the browser), Pal ships the machinery.
public typealias WebNavigationPolicy = @MainActor (WebNavigationRequest) -> WebNavigationDecision
