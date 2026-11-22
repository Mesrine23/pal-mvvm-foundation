import Foundation

/// Checks a String Catalog (`.xcstrings`) for the mistakes the compiler can't see:
/// a key missing a language shows the raw key, a translation that changes a
/// placeholder's type crashes, one that drops a placeholder loses its value, `%%` in
/// a key without placeholders shows as `%%`, an entry Xcode extracted instead of one
/// added by hand has no generated symbol, and a key written twice keeps one value.
///
/// Apps copy this file into their own test target and point a test at their catalog.
enum CatalogCheck {

    /// One mistake in one key.
    struct Problem: Hashable, CustomStringConvertible {
        let key: String
        let issue: String

        var description: String { "\(key): \(issue)" }
    }

    /// One printf-style placeholder: its argument position and its type.
    struct Placeholder: Hashable {
        let position: Int
        let kind: String
    }

    /// Every problem in the catalog at `url`; empty when the catalog is sound.
    static func problems(in url: URL) throws -> Set<Problem> {
        let data = try Data(contentsOf: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let source = root["sourceLanguage"] as? String ?? "en"
        let strings = root["strings"] as? [String: [String: Any]] ?? [:]
        let languages = Set(strings.values.flatMap { localizations(of: $0).keys })
        let text = String(decoding: data, as: UTF8.self)
        var problems: Set<Problem> = []

        for (key, entry) in strings {
            if entries(named: key, in: text) > 1 {
                problems.insert(Problem(key: key, issue: "written more than once; the build keeps the first"))
            }
            guard entry["extractionState"] as? String == "manual" else {
                problems.insert(Problem(key: key, issue: "not a manual key, so it has no symbol"))
                continue
            }
            let byLanguage = localizations(of: entry)
            for language in languages.subtracting(byLanguage.keys).sorted() {
                problems.insert(Problem(key: key, issue: "no \(language) value"))
            }
            guard let sourceValues = byLanguage[source].map(values(of:)), let reference = sourceValues.last else {
                continue
            }
            let expected = placeholders(in: reference)
            for value in sourceValues where expected.isEmpty && value.contains("%%") {
                problems.insert(Problem(key: key, issue: "%% in a key without placeholders shows as %%"))
            }
            for (language, localization) in byLanguage where language != source {
                for value in values(of: localization) {
                    let found = placeholders(in: value)
                    let changesAType = found.contains { slot in
                        expected.contains { $0.position == slot.position && $0.kind != slot.kind }
                    }
                    if changesAType {
                        problems.insert(Problem(key: key, issue: "\(language) changes a placeholder's type"))
                    } else if found.count < expected.count, !isPluralOne(value, of: localization) {
                        problems.insert(Problem(key: key, issue: "\(language) drops a placeholder"))
                    }
                }
            }
        }
        return problems
    }

    /// The printf-style placeholders in `value`, with `%%` skipped and positions
    /// resolved (`%2$@` is position 2). Prose such as "20% off" isn't one: like Xcode's
    /// symbol generator, the pattern allows no space flag.
    static func placeholders(in value: String) -> [Placeholder] {
        let pattern = /%(?:(\d+)\$)?[-+0#]*\d*(?:\.\d+)?(hh|h|ll|l|q|z|t|j)?([@dDiuUxXoOfFeEgGcCsSaA%])/
        var result: [Placeholder] = []
        var next = 1
        for match in value.matches(of: pattern) where match.output.3 != "%" {
            let position = match.output.1.flatMap { Int($0) } ?? next
            let conversion = String(match.output.3)
            let floating = ["f", "F", "e", "E", "g", "G"].contains(conversion)
            let kind = (match.output.2.map(String.init) ?? "") + (floating ? "f" : conversion)
            result.append(Placeholder(position: position, kind: kind))
            next = position + 1
        }
        return result
    }

    // JSON parsers silently keep one of two entries with the same key, so the raw
    // text is the only place a duplicate shows.
    private static func entries(named key: String, in text: String) -> Int {
        let escaped = NSRegularExpression.escapedPattern(for: key)
        guard let pattern = try? NSRegularExpression(pattern: "\"\(escaped)\"\\s*:\\s*\\{") else { return 0 }
        return pattern.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func localizations(of entry: [String: Any]) -> [String: [String: Any]] {
        entry["localizations"] as? [String: [String: Any]] ?? [:]
    }

    private static func values(of localization: [String: Any]) -> [String] {
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
            return [value]
        }
        let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]] ?? [:]
        return ["zero", "one", "two", "few", "many", "other"].compactMap { category in
            (plural[category]?["stringUnit"] as? [String: Any])?["value"] as? String
        }
    }

    // A plural's "one" form may leave the count out ("One favorite").
    private static func isPluralOne(_ value: String, of localization: [String: Any]) -> Bool {
        let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]]
        return (plural?["one"]?["stringUnit"] as? [String: Any])?["value"] as? String == value
    }
}
