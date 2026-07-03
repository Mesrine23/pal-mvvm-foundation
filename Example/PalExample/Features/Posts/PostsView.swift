import SwiftUI
import PalDesignSystem
import PalPresentation

/// The paginated posts list — the canonical pagination pattern: rows in the
/// `ForEach`, the paging footer OUTSIDE it, `onAppear` of the footer triggering
/// the next page.
struct PostsView: View {

    @State private var viewModel: PostsViewModel

    init(viewModel: PostsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Posts")
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.posts.state {
        case .idle, .loading(previous: nil):
            list(Post.placeholders).skeleton(when: true)
        case .loading(previous: let cached?):
            list(cached)
        case .loaded(let posts):
            list(posts)
        case .failed(let error, previous: nil):
            ErrorView(error) { viewModel.reload() }
        case .failed(_, previous: let cached?):
            list(cached)
        }
    }

    private func list(_ posts: [Post]) -> some View {
        List {
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title).textStyle(.headline)
                    Text(post.body).textStyle(.caption).lineLimit(2)
                }
            }
            if viewModel.posts.hasMore {
                pagingFooter
                    // A fresh identity per page re-fires onAppear when a short
                    // page leaves the footer visible (it would otherwise fire once).
                    .id(posts.count)
                    .onAppear { viewModel.loadMore() }
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private var pagingFooter: some View {
        if let error = viewModel.posts.loadMoreError {
            SectionErrorView(error) { viewModel.loadMore() }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }
}
