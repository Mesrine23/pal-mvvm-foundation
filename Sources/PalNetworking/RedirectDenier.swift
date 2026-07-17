import Foundation

/// The per-task delegate behind ``RedirectPolicy/deny``: refuses the redirect,
/// so the 3xx itself becomes the final response and flows into the normal
/// non-2xx path with its headers (`Location` included) intact.
final class RedirectDenier: NSObject, URLSessionTaskDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
