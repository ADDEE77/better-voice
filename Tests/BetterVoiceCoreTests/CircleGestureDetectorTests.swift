import CoreGraphics
import XCTest
@testable import BetterVoiceCore

final class CircleGestureDetectorTests: XCTestCase {
    func testTrailSegmentRangeHandlesEmptyAndShortTrails() {
        XCTAssertEqual(Array(trailSegmentRange(pointCount: 0)), [])
        XCTAssertEqual(Array(trailSegmentRange(pointCount: 1)), [])
        XCTAssertEqual(Array(trailSegmentRange(pointCount: 3)), [1, 2])
    }

    func testRecognizesClosedCircle() {
        var detector = CircleGestureDetector()
        var result: CircleGesture?
        let center = CGPoint(x: 300, y: 200)

        for index in 0..<48 {
            let angle = CGFloat(index) / 47 * 2 * .pi
            result = detector.add(
                point: CGPoint(x: center.x + 52 * cos(angle), y: center.y + 52 * sin(angle)),
                at: Double(index) / 60
            ) ?? result
        }

        XCTAssertEqual(result?.center.x ?? 0, center.x, accuracy: 3)
        XCTAssertEqual(result?.center.y ?? 0, center.y, accuracy: 3)
        XCTAssertEqual(result?.radius ?? 0, 52, accuracy: 3)
    }

    func testRejectsStraightLine() {
        var detector = CircleGestureDetector()
        var result: CircleGesture?

        for index in 0..<48 {
            result = detector.add(
                point: CGPoint(x: CGFloat(index) * 4, y: 200),
                at: Double(index) / 60
            ) ?? result
        }

        XCTAssertNil(result)
    }
}
