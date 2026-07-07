import SwiftUI

/// A wrapping horizontal flow: subviews lay out left-to-right and break to a
/// new row when the width runs out — chips, tags, token lists.
///
/// ```swift
/// FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
///     ForEach(tags) { TagChip($0) }
/// }
/// ```
public struct FlowLayout: Layout {

    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat

    /// Creates a flow layout.
    /// - Parameters:
    ///   - horizontalSpacing: The gap between items on a row.
    ///   - verticalSpacing: The gap between rows.
    public init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return arrangement(of: sizes, in: proposal.width ?? .infinity).size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = arrangement(of: sizes, in: bounds.width).offsets
        for (subview, offset) in zip(subviews, offsets) {
            subview.place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangement(of sizes: [CGSize], in containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for size in sizes {
            if x > 0, x + size.width > containerWidth {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x - horizontalSpacing)
        }
        return (offsets, CGSize(width: maxRowWidth, height: y + rowHeight))
    }
}
