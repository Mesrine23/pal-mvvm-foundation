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
                    LabeledContent(.userDetailEmail, value: viewModel.user.email)
                }
                LabeledContent(.userDetailCompany, value: viewModel.user.company)
            }
            Section {
                Button {
                    viewModel.toggleFavorite()
                } label: {
                    Label(
                        viewModel.isFavorite ? .userDetailRemoveFavorite : .userDetailAddFavorite,
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
