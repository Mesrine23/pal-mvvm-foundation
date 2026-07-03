/// Placeholder users that size the skeleton rows on first load. The values are
/// masked by `.skeleton(when:)` and never rendered — length only shapes the bars.
extension User {

    static let placeholders: [User] = (1...8).map { index in
        User(
            id: -index,
            name: "Placeholder Person Name",
            email: "placeholder@example.com",
            company: "Placeholder Company"
        )
    }
}
