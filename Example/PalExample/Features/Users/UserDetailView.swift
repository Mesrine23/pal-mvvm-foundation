import SwiftUI
import PalDesignSystem

/// Shows a user's details with a persisted favorite toggle.
struct UserDetailView: View {

    @State private var viewModel: UserDetailViewModel

    init(viewModel: UserDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                if viewModel.showsEmail {
                    LabeledContent("Email", value: viewModel.user.email)
                }
                LabeledContent("Company", value: viewModel.user.company)
            }
            Section {
                Button {
                    viewModel.toggleFavorite()
                } label: {
                    Label(
                        viewModel.isFavorite ? "Remove from favorites" : "Add to favorites",
                        systemImage: viewModel.isFavorite ? "star.fill" : "star"
                    )
                }
            }
        }
        .navigationTitle(viewModel.user.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
    }
}
