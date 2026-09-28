import Foundation

/// ``Loader``'s sibling for paginated lists: the accumulated items drive the
/// same ``ViewState`` machine (the screen's switch is unchanged), while
/// ``loadMore()`` appends pages with its own footer-sized state — a failed
/// load-more never touches the list.
///
/// Unlike `Loader`, the operation is injected at `init`: the loader must
/// re-invoke it with successive cursors (`nil` = first page).
///
/// As with `Loader`, **the newest first-page call wins**: whichever of
/// ``load()``, ``performLoad()``, or ``refresh()`` started last owns the list,
/// and a load-more started before that reload never appends to it. ``cancel()``
/// discards every in-flight result the same way.
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
    private var generation = 0

    /// Creates a paged loader over the page-fetching operation.
    /// - Parameter operation: Fetches one page for a cursor (`nil` = the first page).
    public init(_ operation: @escaping @Sendable (Cursor?) async throws -> Page<Item, Cursor>) {
        self.operation = operation
    }

    /// Loads (or reloads) the first page through the state machine, cancelling
    /// any in-flight work first. Fire-and-forget — buttons, delegates, retry.
    public func load() {
        let generation = beginFirstPage()
        state = .loading(previous: state.value)
        task = Task { [weak self] in
            await self?.runFirstPage(generation: generation)
        }
    }

    /// The awaitable first-page variant for `.task { }` integration: the view's
    /// lifecycle cancels the work when the view disappears.
    public func performLoad() async {
        let generation = beginFirstPage()
        state = .loading(previous: state.value)
        await runFirstPage(generation: generation)
    }

    /// Reloads from the first page for **pull-to-refresh**: no `.loading`
    /// transition (the refresh control is the indicator), current items stay
    /// visible until the fresh first page replaces them.
    public func refresh() async {
        let generation = beginFirstPage()
        await runFirstPage(generation: generation)
    }

    /// Fetches the next page and appends it. Fire-and-forget — trigger it from
    /// the appearance of the trailing footer row. No-ops while the first page or
    /// another load-more is in flight, before the first page has loaded, and
    /// after the last page.
    public func loadMore() {
        guard let current = beginLoadMore() else { return }
        let cursor = nextCursor
        let generation = self.generation
        loadMoreTask = Task { [weak self] in
            await self?.runLoadMore(from: current, cursor: cursor, generation: generation)
        }
    }

    /// The awaitable next-page variant, mirroring ``performLoad()``: same guards
    /// and state transitions as ``loadMore()``, but callers await completion —
    /// no polling of ``isLoadingMore`` in tests, tools, or prefetching flows.
    /// Cancellation rides the caller's task; ``cancel()`` doesn't interrupt it but
    /// discards its result.
    public func performLoadMore() async {
        guard let current = beginLoadMore() else { return }
        await runLoadMore(from: current, cursor: nextCursor, generation: generation)
    }

    /// Cancels any in-flight work without changing state. An awaited
    /// ``performLoad()``, ``refresh()``, or ``performLoadMore()`` still running
    /// is not interrupted, but its result is discarded.
    public func cancel() {
        task?.cancel()
        task = nil
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadingFirstPage = false
        isLoadingMore = false
        generation &+= 1
    }

    private func beginFirstPage() -> Int {
        task?.cancel()
        loadMoreTask?.cancel()
        isLoadingFirstPage = true
        isLoadingMore = false
        loadMoreError = nil
        generation &+= 1
        return generation
    }

    private func isCurrent(_ generation: Int) -> Bool {
        !Task.isCancelled && generation == self.generation
    }

    private func beginLoadMore() -> [Item]? {
        guard !isLoadingFirstPage, !isLoadingMore, hasMore, let current = state.value else { return nil }
        isLoadingMore = true
        loadMoreError = nil
        return current
    }

    private func runLoadMore(from current: [Item], cursor: Cursor?, generation: Int) async {
        do {
            let page = try await operation(cursor)
            guard isCurrent(generation) else { return }
            state = .loaded(current + page.items)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            isLoadingMore = false
        } catch is CancellationError {
        } catch {
            guard isCurrent(generation) else { return }
            loadMoreError = PresentableError(from: error)
            isLoadingMore = false
        }
    }

    private func runFirstPage(generation: Int) async {
        do {
            let page = try await operation(nil)
            guard isCurrent(generation) else { return }
            state = .loaded(page.items)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            isLoadingFirstPage = false
        } catch is CancellationError {
        } catch {
            guard isCurrent(generation) else { return }
            state = .failed(PresentableError(from: error), previous: state.value)
            isLoadingFirstPage = false
        }
    }
}
