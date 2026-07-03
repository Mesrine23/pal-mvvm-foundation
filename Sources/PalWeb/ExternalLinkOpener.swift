#if canImport(UIKit)
import UIKit

/// Opens URLs in the system browser (or their registered universal-link app)
/// from **non-View contexts** — ViewModels and coordinators. Inside SwiftUI
/// Views, prefer the environment's `openURL` action or a `Link`.
@MainActor
@available(iOSApplicationExtension, unavailable)
public struct ExternalLinkOpener {

    /// Creates an opener.
    public init() {}

    /// Opens the URL externally.
    public func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
#endif
