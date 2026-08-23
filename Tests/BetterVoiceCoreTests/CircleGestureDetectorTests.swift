import CoreGraphics
import XCTest
@testable import BetterVoiceCore

final class CircleGestureDetectorTests: XCTestCase {
    func testTrailSegmentsSkipPausesAndPointerJumps() {
        XCTAssertEqual(trailSegments(points: [], times: []), [])
        XCTAssertEqual(
            trailSegments(points: [CGPoint(x: 0, y: 0)], times: [0]),
            []
        )
        XCTAssertEqual(
            trailSegments(
                points: [CGPoint(x: 0, y: 0), CGPoint(x: 4, y: 3)],
                times: [0, 0.016]
            ),
            [TrailSegment(from: 0, to: 1)]
        )
        XCTAssertEqual(
            trailSegments(
                points: [CGPoint(x: 0, y: 0), CGPoint(x: 4, y: 3)],
                times: [0, 0.25]
            ),
            []
        )
        XCTAssertEqual(
            trailSegments(
                points: [CGPoint(x: 0, y: 0), CGPoint(x: 240, y: 0)],
                times: [0, 0.016]
            ),
            []
        )
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
