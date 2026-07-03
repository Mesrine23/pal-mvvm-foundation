import SwiftUI
import PalDesignSystem
import PalPresentation

/// Renders the users list by switching on the loader's ``ViewState``.
struct UsersListView: View {

    @State private var viewModel: UsersListViewModel

    init(viewModel: UsersListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Users")
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.users.state {
        case .idle, .loading(previous: nil):
            list(User.placeholders).skeleton(when: true)
        case .loading(previous: let cached?):
            list(cached)
        case .loaded(let users):
            list(users)
        case .failed(let error, previous: nil):
            ErrorView(error) { viewModel.reload() }
        case .failed(_, previous: let cached?):
            list(cached)
        }
    }

    private func list(_ users: [User]) -> some View {
        List(users) { user in
            Button {
                viewModel.select(user)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name).textStyle(.headline)
                    Text(user.company).textStyle(.caption)
                }
            }
            .buttonStyle(.plain)
        }
        // The empty state is an overlay, not a replacement: swapping the List out
        // while pull-to-refresh is still spinning drops the update (and warns). Keeping
        // the List mounted lets a refreshed-to-empty result render on the first pull.
        .overlay {
            if users.isEmpty {
                EmptyStateView(
                    systemImage: "person.slash",
                    title: String(localized: "No users"),
                    message: String(localized: "There is nothing to show yet."),
                    actionTitle: String(localized: "Reload"),
                    action: { viewModel.reload() }
                )
            }
        }
        .refreshable { await viewModel.refresh() }
    }
}
