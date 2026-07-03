/// What the app's navigation policy decides for one attempted navigation.
public enum WebNavigationDecision: Sendable, Equatable {

    /// Load it in the web view.
    case allow

    /// Block it silently.
    case cancel

    /// Block it in the web view and open the URL in the external browser instead
    /// (the classic "links leave the app" policy).
    case openExternally
}
