import Foundation

/// ``Loader``'s sibling for paginated lists: the accumulated items drive the
/// same ``ViewState`` machine (the screen's switch is unchanged), while
/// ``loadMore()`` appends pages with its own footer-sized state — a failed
/// load-more never touches the list.
///
/// Unlike `Loader`, the operation is injected at `init`: the loader must
/// re-invoke it with successive cursors (`nil` = first page).
///
/// ```swift
/// @MainActor @Observable
/// final class PostsViewModel {
///     let posts: PagedLoader<Post, Int>
///     init(fetchPosts: FetchPostsUseCaseProtocol) {
///         posts = PagedLoader { page in try await fetchPosts.execute(page: page ?? 1) }
///     }
/// }
/// // The trailing row sits OUTSIDE the ForEach and triggers the next page:
/// // List {
/// //     ForEach(items) { PostRow($0) }
/// //     if viewModel.posts.hasMore { PagingFooter().onAppear { viewModel.posts.loadMore() } }
/// // }
/// ```
@MainActor
@Observable
public final class PagedLoader<Item: Sendable, Cursor: Sendable> {

    /// The accumulated items across all loaded pages, driven through the same
    /// four states as a ``Loader``. Read-only externally.
    public private(set) var state: ViewState<[Item]> = .idle

    /// Whether a next-page fetch is in flight — drives the footer spinner.
    public private(set) var isLoadingMore = false

    /// Whether another page exists. `false` after a page returns `nextCursor: nil`;
    /// the footer disappears (or shows an end-of-list note).
    public private(set) var hasMore = true

    /// Set when a load-more fails (the list keeps its items); cleared by the next
    /// ``loadMore()`` — a footer retry button just calls `loadMore()` again.
    public private(set) var loadMoreError: PresentableError?

    private let operation: @Sendable (Cursor?) async throws -> Page<Item, Cursor>
    private var nextCursor: Cursor?
    private var isLoadingFirstPage = false
    private var task: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    /// Creates a paged loader over the page-fetching operation.
    /// - Parameter operation: Fetches one page for a cursor (`nil` = the first page).
    public init(_ operation: @escaping @Sendable (Cursor?) async throws -> Page<Item, Cursor>) {
        self.operation = operation
    }

    /// Loads (or reloads) the first page through the state machine, cancelling
    /// any in-flight work first. Fire-and-forget — buttons, delegates, retry.
    public func load() {
        beginFirstPage()
        state = .loading(previous: state.value)
        task = Task { [weak self] in
            await self?.runFirstPage()
        }
    }

    /// The awaitable first-page variant for `.task { }` integration: the view's
    /// lifecycle cancels the work when the view disappears.
    public func performLoad() async {
        beginFirstPage()
        state = .loading(previous: state.value)
        await runFirstPage()
    }

    /// Reloads from the first page for **pull-to-refresh**: no `.loading`
    /// transition (the refresh control is the indicator), current items stay
    /// visible until the fresh first page replaces them.
    public func refresh() async {
        beginFirstPage()
        await runFirstPage()
    }

    /// Fetches the next page and appends it. Fire-and-forget — trigger it from
    /// the appearance of the trailing footer row. No-ops while the first page or
    /// another load-more is in flight, before the first page has loaded, and
    /// after the last page.
    public func loadMore() {
        guard !isLoadingFirstPage, !isLoadingMore, hasMore, let current = state.value else { return }
        isLoadingMore = true
        loadMoreError = nil
        let cursor = nextCursor
        loadMoreTask = Task { [weak self, operation] in
            do {
                let page = try await operation(cursor)
                guard !Task.isCancelled, let self else { return }
                self.state = .loaded(current + page.items)
                self.nextCursor = page.nextCursor
                self.hasMore = page.nextCursor != nil
                self.isLoadingMore = false
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.loadMoreError = PresentableError(from: error)
                self.isLoadingMore = false
            }
        }
    }

    /// Cancels any in-flight work without changing state.
    public func cancel() {
        task?.cancel()
        task = nil
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadingFirstPage = false
        isLoadingMore = false
    }

    private func beginFirstPage() {
        task?.cancel()
        loadMoreTask?.cancel()
        isLoadingFirstPage = true
        isLoadingMore = false
        loadMoreError = nil
    }

    private func runFirstPage() async {
        do {
            let page = try await operation(nil)
            guard !Task.isCancelled else { return }
            state = .loaded(page.items)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            isLoadingFirstPage = false
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(PresentableError(from: error), previous: state.value)
            isLoadingFirstPage = false
        }
    }
}
