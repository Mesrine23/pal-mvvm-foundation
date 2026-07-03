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
}
