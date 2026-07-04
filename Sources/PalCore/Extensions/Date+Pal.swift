import Foundation

public extension Date {

    /// Parses an ISO 8601 string, with or without fractional seconds.
    /// - Parameter string: A string such as `"2026-06-13T09:41:00Z"` or
    ///   `"2026-06-13T09:41:00.123Z"`.
    init?(iso8601 string: String) {
        if let date = try? Date(string, strategy: Date.ISO8601FormatStyle()) {
            self = date
        } else if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            self = date
        } else {
            return nil
        }
    }

    /// The date formatted as an ISO 8601 string in UTC.
    var iso8601String: String {
        formatted(Date.ISO8601FormatStyle())
    }

    /// `true` when both dates fall on the same calendar day.
    /// - Parameters:
    ///   - other: The date to compare against.
    ///   - calendar: The calendar defining day boundaries. Defaults to the current calendar.
    func isSameDay(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }
}
