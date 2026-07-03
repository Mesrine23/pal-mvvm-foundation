import SwiftUI
import Testing
@testable import PalDesignSystem

@MainActor
@Suite("DesignSystem doc snippets")
struct DesignSystemSnippetTests {

    @Test("Scroll-observation snippet compiles (target + offset + reached-bottom)")
    func scrollObservationSnippetCompiles() {
        _ = ScrollView {
            Text("content").scrollObservationTarget()
        }
        .onScrollOffsetChange { _ in }
        .onReachedBottom(threshold: 100) {}
    }

    @Test("Shimmer and skeleton snippets compile")
    func shimmerSnippetsCompile() {
        _ = Text("placeholder").shimmering(active: true)
        _ = Text("row").skeleton(when: true)
    }

    @Test("Toast snippet compiles and carries its defaults")
    func toastSnippetCompiles() {
        let binding = Binding<AppToast?>(get: { nil }, set: { _ in })
        _ = Text("screen").appToast(binding)

        let toast = AppToast(kind: .success, title: "Saved")
        #expect(toast.duration == .seconds(3))
        #expect(toast.message == nil)
    }
}
