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

    func testRepeatedModifierEventDoesNotShortenHold() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0.2))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.3))
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0.4))
    }

    func testSecondTapReleaseDoesNotArmAnotherTap() {
        var detector = ModifierDoubleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.1))
        XCTAssertTrue(detector.modifierChanged(active: true, now: 0.2))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.3))
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0.4))
    }
}

final class ModifierToggleTapDetectorTests: XCTestCase {
    func testShortTapToggles() {
        var detector = ModifierToggleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertTrue(detector.modifierChanged(active: false, now: 0.1))
    }

    func testHoldDoesNotToggle() {
        var detector = ModifierToggleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.5))
    }

    func testModifierComboCancelsTap() {
        var detector = ModifierToggleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        detector.nonModifierKeyPressed()
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.1))
    }

    func testRepeatedModifierEventDoesNotShortenHold() {
        var detector = ModifierToggleTapDetector()
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0))
        XCTAssertFalse(detector.modifierChanged(active: true, now: 0.2))
        XCTAssertFalse(detector.modifierChanged(active: false, now: 0.3))
    }
}

final class RecordingTriggerModeTests: XCTestCase {
    func testQuickModesForModifierOnlyBinding() {
        XCTAssertEqual(
            RecordingTriggerMode.availableModes(forQuick: true, modifierOnly: true),
            [.hold, .toggle, .doubleTap]
        )
    }

    func testQuickModesForKeyComboBinding() {
        XCTAssertEqual(
            RecordingTriggerMode.availableModes(forQuick: true, modifierOnly: false),
            [.hold, .toggle]
        )
    }

    func testLongModesForModifierOnlyBinding() {
        XCTAssertEqual(
            RecordingTriggerMode.availableModes(forQuick: false, modifierOnly: true),
            [.toggle, .doubleTap]
        )
    }

    func testHoldDetailIncludesMilliseconds() {
        XCTAssertTrue(
            RecordingTriggerMode.hold.detail(bindingLabel: "⌥", holdDelayMilliseconds: 200).contains("200 ms")
        )
    }
}
