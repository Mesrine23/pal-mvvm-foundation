import SwiftUI
import PalDesignSystem
import PalPresentation
import PalWeb

/// The About page: an embedded web view dogfooding `WebScreen` — `ViewState`
/// composition, a live progress bar and title, and the navigation policy
/// (GitHub stays in, everything else opens externally).
struct AboutPalView: View {

    @State private var page = WebPageModel()

    var body: some View {
        WebScreen(
            url: AppConfig.repositoryURL,
            page: page,
            policy: { request in
                request.url.host()?.hasSuffix("github.com") == true ? .allow : .openExternally
            }
        )
        .overlay {
            if let error = page.state.error {
                ErrorView(error) { page.reload() }
            } else if page.state.isLoading, page.state.value == nil {
                LoadingView(message: String(localized: "Loading page…"))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if page.state.isLoading {
                ProgressView(value: page.progress)
                    .progressViewStyle(.linear)
            }
        }
        .navigationTitle(page.title ?? String(localized: "About Pal"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
