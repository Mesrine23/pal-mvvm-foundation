#if canImport(SwiftUI)
import SwiftUI
import Testing
@testable import PalPresentation

private struct SnippetPost: Identifiable, Sendable {
    let id: Int
}

@MainActor
@Suite("Pagination doc snippet")
struct PaginationSnippetTests {

    @Test("The GettingStarted pattern compiles — paging footer outside the ForEach")
    func paginationPatternCompiles() {
        let loader = PagedLoader<SnippetPost, Int> { page in
            Page(items: [], nextCursor: (page ?? 1) + 1)
        }
        let posts = loader.state.value ?? []
        _ = List {
            ForEach(posts) { post in
                Text(String(post.id))
            }
            if loader.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .id(posts.count)
                    .onAppear { loader.loadMore() }
            }
        }
    }
}
#endif
