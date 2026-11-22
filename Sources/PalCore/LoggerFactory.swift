import Foundation
import os

/// Creates `os.Logger` instances with a unified subsystem so all Pal-based
/// logging is filterable per category in Console.app and Xcode.
///
/// Logging is opt-in: nothing logs unless a call site creates a logger and uses it.
/// Under member-import visibility, which new Xcode projects turn on, a file that
/// logs also imports `os`, the module that declares `Logger`'s members.
///
/// ```swift
/// import os
///
/// private let logger = LoggerFactory.make(category: "Networking")
/// logger.debug("→ GET /users")
/// ```
public enum LoggerFactory {

    /// Creates a logger for the given category, using the host app's bundle
    /// identifier as the subsystem.
    /// - Parameter category: A short, stable name for the area emitting logs
    ///   (e.g. `"Networking"`, `"Persistence"`, a feature name).
    /// - Returns: A ready-to-use `os.Logger`.
    public static func make(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "Pal"
}
