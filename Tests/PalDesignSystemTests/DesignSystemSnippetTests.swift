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

    @Test("Hex colors parse the documented shapes and reject the rest")
    func hexColorsParse() {
        _ = Color(hex: 0xF3F1EC)
        _ = Color(hex: 0xF3F1EC, opacity: 0.5)
        #expect(Color(hex: "#F3F1EC") != nil)
        #expect(Color(hex: "F3F1EC") != nil)
        #expect(Color(hex: "#F3F1ECCC") != nil)
        #expect(Color(hex: "F3F1") == nil)
        #expect(Color(hex: "not-a-color") == nil)
    }

    @Test("FlowLayout snippet compiles as a layout container")
    func flowLayoutSnippetCompiles() {
        _ = FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Text(String(index))
            }
        }
    }

    @Test("surfaceElevated defaults to surface and stays settable")
    func surfaceElevatedDefaults() {
        var colors = ThemeColors.system
        colors.surfaceElevated = .red

        let defaulted = ThemeColors(
            background: .white,
            surface: .gray,
            textPrimary: .black,
            textSecondary: .gray,
            accent: .blue,
            success: .green,
            warning: .orange,
            danger: .red
        )
        #expect(defaulted.surfaceElevated == defaulted.surface)
    }
}
