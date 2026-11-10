//
//  AdaptiveGridLayout.swift
//  Pelagica
//

import SwiftUI

struct AdaptiveGridLayout: Layout {
    var minimumItemWidth: CGFloat
    var horizontalSpacing: CGFloat = 40
    var verticalSpacing: CGFloat = 60

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minimumItemWidth
        let rows = rowHeights(for: subviews, width: width)
        let height = rows.reduce(0, +) + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columnCount(for: bounds.width)
        let itemWidth = itemWidth(for: bounds.width, columns: columns)
        let itemProposal = ProposedViewSize(width: itemWidth, height: nil)
        var y = bounds.minY
        for (row, height) in rowHeights(for: subviews, width: bounds.width).enumerated() {
            for column in 0..<columns {
                let index = row * columns + column
                guard index < subviews.count else { break }
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (itemWidth + horizontalSpacing), y: y),
                    proposal: itemProposal
                )
            }
            y += height + verticalSpacing
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        max(1, Int((width + horizontalSpacing) / (minimumItemWidth + horizontalSpacing)))
    }

    private func itemWidth(for width: CGFloat, columns: Int) -> CGFloat {
        max(0, (width - horizontalSpacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    private func rowHeights(for subviews: Subviews, width: CGFloat) -> [CGFloat] {
        let columns = columnCount(for: width)
        let itemProposal = ProposedViewSize(width: itemWidth(for: width, columns: columns), height: nil)
        return stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(itemProposal).height }
                .max() ?? 0
        }
    }
}
