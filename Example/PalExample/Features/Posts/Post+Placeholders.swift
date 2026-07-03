/// Placeholder posts that size the skeleton rows on first load. The values are
/// masked by `.skeleton(when:)` and never rendered — length only shapes the bars.
extension Post {

    static let placeholders: [Post] = (1...8).map { index in
        Post(
            id: -index,
            title: "Placeholder post title",
            body: "Placeholder body text that wraps to roughly two lines of content."
        )
    }
}
