import CoreGraphics
import Foundation

enum SquarifiedTreemap {
    static func rects(values: [Double], in bounds: CGRect) -> [CGRect] {
        guard !values.isEmpty else {
            return []
        }
        let safeValues = values.map { $0.isFinite ? max(0, $0) : 0 }
        let total = safeValues.reduce(0, +)
        guard total > 0, bounds.width > 0, bounds.height > 0 else {
            return Array(repeating: .zero, count: values.count)
        }

        let scale = bounds.width * bounds.height / total
        let areas = safeValues.map { $0 * scale }
        var ordered = Array(repeating: CGRect.zero, count: areas.count)
        var row: [Int] = []
        var index = 0
        var remaining = bounds

        while index < areas.count {
            let side = min(remaining.width, remaining.height)
            guard side > 0 else {
                break
            }
            let currentWorst = row.isEmpty ? .infinity : worstScore(row, areas: areas, side: side)
            let candidateWorst = worstScore(row + [index], areas: areas, side: side)
            if row.isEmpty || candidateWorst <= currentWorst {
                row.append(index)
                index += 1
            } else {
                layoutRow(row, areas: areas, in: &remaining, result: &ordered)
                row = []
            }
        }
        if !row.isEmpty {
            layoutRow(row, areas: areas, in: &remaining, result: &ordered)
        }
        return ordered
    }

    private static func worstScore(_ positions: [Int], areas: [Double], side: CGFloat) -> Double {
        let rowAreas = positions.map { areas[$0] }
        guard let maxValue = rowAreas.max(),
              let minValue = rowAreas.min(),
              minValue > 0 else {
            return .infinity
        }
        let sum = rowAreas.reduce(0, +)
        let sideSquared = Double(side * side)
        let sumSquared = sum * sum
        return max(
            sideSquared * maxValue / sumSquared,
            sumSquared / (sideSquared * minValue)
        )
    }

    private static func layoutRow(
        _ positions: [Int],
        areas: [Double],
        in remaining: inout CGRect,
        result: inout [CGRect]
    ) {
        let sum = positions.reduce(0.0) { $0 + areas[$1] }
        guard sum > 0 else {
            return
        }

        if remaining.width >= remaining.height {
            let width = min(remaining.width, sum / remaining.height)
            var y = remaining.minY
            for position in positions {
                let height = min(max(0, width > 0 ? areas[position] / width : 0), remaining.maxY - y)
                result[position] = CGRect(x: remaining.minX, y: y, width: width, height: height)
                y += height
            }
            remaining.size.width = max(0, remaining.width - width)
            remaining.origin.x += width
        } else {
            let height = min(remaining.height, sum / remaining.width)
            var x = remaining.minX
            for position in positions {
                let width = min(max(0, height > 0 ? areas[position] / height : 0), remaining.maxX - x)
                result[position] = CGRect(x: x, y: remaining.minY, width: width, height: height)
                x += width
            }
            remaining.size.height = max(0, remaining.height - height)
            remaining.origin.y += height
        }
    }
}
