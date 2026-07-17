/// How the transport treats 3xx redirects for a request.
public enum RedirectPolicy: Sendable, Hashable {

    /// Follow redirects transparently — `URLSession`'s default behavior and the
    /// right choice for almost every request.
    case follow

    /// Refuse to follow: the 3xx becomes the final response and surfaces as
    /// ``NetworkError/unacceptableStatus(code:data:headers:)`` with the
    /// `Location` header readable via ``NetworkError/responseHeaders`` — the
    /// caller decides what happens next.
    case deny
}
