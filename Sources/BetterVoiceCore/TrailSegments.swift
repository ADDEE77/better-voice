/// Returns the indices that have a preceding point and can therefore form trail segments.
public func trailSegmentRange(pointCount: Int) -> Range<Int> {
    pointCount > 1 ? 1..<pointCount : 0..<0
}
