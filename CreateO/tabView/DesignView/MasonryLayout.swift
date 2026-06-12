
import SwiftUI

struct MasonryLayout: Layout {
    var columns: Int
    var spacing: Double
    
    init(columns: Int, spacing: Double) {
        self.columns = max(1, columns)
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let viewFrames = frames(for: subviews, in: width)
        let height = viewFrames.max { $0.maxY < $1.maxY } ?? .zero
        return CGSize(width: width, height: height.maxY)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let viewFrames = frames(for: subviews, in: bounds.width)
        
        for index in subviews.indices {
            let frame = viewFrames[index]
            let position = CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY)
            subviews[index].place(at: position, proposal: ProposedViewSize(frame.size))
        }
     }
    
    func frames(for subviews: Subviews, in totalWidth: Double) -> [CGRect] {
        
        let totalSpacing = spacing * Double(columns - 1)
        let columnWidth = (totalWidth - totalSpacing) / Double(columns)
        let columnWidthWithSpacing = columnWidth + spacing
        let proposedSize = ProposedViewSize(width: columnWidth, height: nil)
        
        var viewFrames = [CGRect]()
        var columnHeights = Array(repeating: 0.0, count: columns)
        
        for subview in subviews {
            var selectedColumn = 0
            var selectedHeight = Double.greatestFiniteMagnitude
            
            for (columnIndex, height) in columnHeights.enumerated() {
                if height < selectedHeight {
                    selectedColumn = columnIndex
                    selectedHeight = height
                }
            }
            
            let x = Double(selectedColumn) * columnWidthWithSpacing
            let y = columnHeights[selectedColumn]
            let size = subview.sizeThatFits(proposedSize)
            let frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            
            columnHeights[selectedColumn] += size.height + spacing
            viewFrames.append(frame)
            
        }
        
        return viewFrames
    }
}
