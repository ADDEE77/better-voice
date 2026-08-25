import XCTest
@testable import BetterVoiceCore

final class ModifierDoubleTapDetectorTests: XCTestCase {
    func testDoubleTapWithinIntervalToggles() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.1))
        XCTAssertTrue(detector.modifierChanged(active: true, now: 0.2))
    }

    func testSingleTapDoesNotToggle() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.1))
        XCTAssertFalse(detector.modifierChanged(active: true, now: 2))
    }

    func testHoldDoesNotToggle() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.5))
    }

    func testModifierComboCancelsPendingTap() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        detector.nonModifierKeyPressed()
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.1))
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0.2))
    }

    func testSlowSecondTapStartsFresh() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.1))
        XCTAssertFalse(detector.modifierChanged(active: true, now: 1))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 1.1))
    }

    func testResetClearsArmedTap() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.1))
        detector.reset()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0.2))
    }
}
