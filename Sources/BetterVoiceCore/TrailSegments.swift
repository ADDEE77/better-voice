import CoreGraphics
import Foundation

public struct TrailSegment: Equatable {
    public let from: Int
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

/// Links only nearby samples so pauses and pointer jumps leave separate tail strokes.
public func trailSegments(
    points: [CGPoint],
    times: [TimeInterval],
    maximumGap: TimeInterval = 0.18,
    maximumDistance: CGFloat = 160
) -> [TrailSegment] {
    guard points.count == times.count, points.count > 1 else { return [] }

    return (1..<points.count).compactMap { index in
        let gap = times[index] - times[index - 1]
        let distance = hypot(
            points[index].x - points[index - 1].x,
            points[index].y - points[index - 1].y
        )
        guard gap >= 0, gap <= maximumGap, distance <= maximumDistance else { return nil }
        return TrailSegment(from: index - 1, to: index)
    }
}
