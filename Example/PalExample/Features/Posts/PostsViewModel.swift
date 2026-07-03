import Observation
import PalAnalytics
import PalPresentation

/// Drives the paginated posts list through a single ``PagedLoader``.
@MainActor @Observable
final class PostsViewModel {

    /// The paged posts — accumulated items drive the screen's `ViewState` switch.
    let posts: PagedLoader<Post, Int>

    @ObservationIgnored private let analytics: any AnalyticsTracker

    init(fetchPage: any FetchPostsPageUseCaseProtocol, analytics: any AnalyticsTracker) {
        self.analytics = analytics
        posts = PagedLoader { page in
            let current = page ?? 1
            let result = try await fetchPage.execute(page: current)
            return Page(items: result.posts, nextCursor: result.hasMore ? current + 1 : nil)
        }
    }

    /// First page via `.task` (view-lifecycle cancellation).
    func load() async {
        analytics.track(.screenViewed("posts"))
        await posts.performLoad()
    }

    /// Full retry from the error state.
    func reload() {
        posts.load()
    }

    /// Pull-to-refresh — restarts from page one, no `.loading` transition.
    func refresh() async {
        await posts.refresh()
    }

    /// The footer trigger — appends the next page.
    func loadMore() {
        posts.loadMore()
    }
}
