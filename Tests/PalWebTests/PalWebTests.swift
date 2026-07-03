import Foundation
import Testing
@testable import PalWeb

private struct SampleError: Error {}

@MainActor
@Suite("WebPageModel")
struct WebPageModelTests {

    @Test("Navigation drives the ViewState machine")
    func navigationDrivesState() {
        let page = WebPageModel()
        #expect(page.state.isLoading == false)

        page.beginNavigation()
        #expect(page.state.isLoading)

        page.finishNavigation()
        guard case .loaded = page.state else {
            Issue.record("Expected .loaded, got \(page.state)")
            return
        }
    }

    @Test("A failed navigation maps to .failed keeping the previous value")
    func failureKeepsPrevious() {
        let page = WebPageModel()
        page.beginNavigation()
        page.finishNavigation()

        page.beginNavigation()
        page.failNavigation(SampleError())

        #expect(page.state.error != nil)
        #expect(page.state.value != nil)
    }

    @Test("A cancelled navigation never surfaces as a failure")
    func cancellationIsSwallowed() {
        let page = WebPageModel()
        page.beginNavigation()

        page.failNavigation(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))

        #expect(page.state.error == nil)
        #expect(page.state.isLoading)
    }

    @Test("Title, progress, and history flags update")
    func observationsUpdate() {
        let page = WebPageModel()

        page.update(title: "Terms")
        page.update(progress: 0.5)
        page.update(canGoBack: true, canGoForward: false)

        #expect(page.title == "Terms")
        #expect(page.progress == 0.5)
        #expect(page.canGoBack)
        #expect(page.canGoForward == false)
    }
}

@Suite("Web navigation values")
struct WebNavigationValueTests {

    @Test("Requests and decisions are value types with sensible equality")
    func valueSemantics() throws {
        let url = try #require(URL(string: "https://example.com/terms"))
        let request = WebNavigationRequest(url: url, isMainFrame: true)

        #expect(request == WebNavigationRequest(url: url, isMainFrame: true))
        #expect(WebNavigationDecision.allow != .openExternally)
    }
}
