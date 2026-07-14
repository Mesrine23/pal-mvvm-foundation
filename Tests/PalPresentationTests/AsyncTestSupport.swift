import Foundation

/// Deterministically waits for a fire-and-forget async operation (a `load`/`loadMore`
/// background `Task`) to drive the observable state to a condition, instead of
/// asserting after a fixed `Task.sleep`. A fixed sleep races the runtime scheduler —
/// a duration that passed on Swift 6.1 can lose the race on 6.3 — so the tests poll
/// the state until it settles, up to a generous timeout (on timeout the following
/// `#expect` fails loudly rather than hanging).
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
    let deadline = ContinuousClock().now + timeout
    while !condition(), ContinuousClock().now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
