/// One page of items plus the cursor that fetches the next one.
///
/// `nextCursor: nil` means the end was reached. The cursor is whatever the API
/// paginates by — an `Int` page index, a `String` opaque cursor, a date…
public struct Page<Item: Sendable, Cursor: Sendable>: Sendable {

    /// The items of this page, in display order.
    public let items: [Item]

    /// The cursor for the next page, or `nil` when this was the last one.
    public let nextCursor: Cursor?

    /// Creates a page.
    public init(items: [Item], nextCursor: Cursor?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

extension Page: Equatable where Item: Equatable, Cursor: Equatable {}
