import Foundation

/// Thrown by ``withTimeout(_:operation:)`` when the operation does not finish in time.
public struct TimeoutError: Error, Sendable, Equatable {

    /// Creates a timeout error.
    public init() {}
}

/// Runs an async operation with a deadline, throwing ``TimeoutError`` if it does not
/// complete in time. The losing side is cancelled via structured concurrency.
///
/// The deadline is only as prompt as the operation's response to cancellation:
/// structured concurrency waits for the cancelled operation to return before
/// `withTimeout` throws. Cancellation-aware work (`URLSession`, `Task.sleep`) stops
/// at once; work that never checks for cancellation — a blocking call, a stuck
/// lock — runs to completion first, so `withTimeout` cannot rescue an operation
/// that hangs.
///
/// ```swift
/// let value = try await withTimeout(.seconds(5)) {
///     try await someSlowOperation()
/// }
/// ```
/// - Parameters:
///   - duration: The maximum time the operation may take.
///   - operation: The async work to race against the deadline.
/// - Returns: The operation's result when it finishes within the deadline.
/// - Throws: ``TimeoutError`` on deadline expiry, or whatever the operation throws.
public func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        group.cancelAll()
        return result
    }
}
