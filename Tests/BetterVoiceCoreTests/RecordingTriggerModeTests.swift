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
    func testCommandOptionUsesPartialStateOnlyForItsOwnModifiers() {
        XCTAssertEqual(
            ModifierBindingState(
                bindingCommand: true,
                bindingOption: true,
                bindingControl: false,
                bindingShift: false,
                command: true,
                option: false,
                control: false,
                shift: false
            ),
            ModifierBindingState(active: false, partial: true)
        )
    }

    func testOptionBindingDoesNotBecomePartialWhenCommandIsHeld() {
        XCTAssertEqual(
            ModifierBindingState(
                bindingCommand: false,
                bindingOption: true,
                bindingControl: false,
                bindingShift: false,
                command: true,
                option: true,
                control: false,
                shift: false
            ),
            ModifierBindingState(active: false, partial: false)
        )
    }

    func testModifierChordWithExtraModifierIsNeitherActiveNorPartial() {
        let state = ModifierBindingState(
            bindingCommand: true,
            bindingOption: true,
            bindingControl: false,
            bindingShift: false,
            command: true,
            option: false,
            control: false,
            shift: true
        )
        XCTAssertFalse(state.active)
        XCTAssertFalse(state.partial)
    }

    func testFullModifierChordIsActiveAndNotPartial() {
        let state = ModifierBindingState(
            bindingCommand: true,
            bindingOption: true,
            bindingControl: false,
            bindingShift: false,
            command: true,
            option: true,
            control: false,
            shift: false
        )
        XCTAssertTrue(state.active)
        XCTAssertFalse(state.partial)
    }

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

final class ModifierChordEngagementTests: XCTestCase {
    private func commandOption(
        command: Bool,
        option: Bool,
        control: Bool = false,
        shift: Bool = false
    ) -> ModifierBindingState {
        ModifierBindingState(
            bindingCommand: true,
            bindingOption: true,
            bindingControl: false,
            bindingShift: false,
            command: command,
            option: option,
            control: control,
            shift: shift
        )
    }

    func testSingleKeyOfAChordDoesNotCountAsPressed() {
        var engagement = ModifierChordEngagement()
        XCTAssertFalse(engagement.isPressed(commandOption(command: true, option: false)))
        XCTAssertFalse(engagement.isPressed(commandOption(command: false, option: false)))
        XCTAssertFalse(engagement.isPressed(commandOption(command: false, option: true)))
    }

    func testFullChordThenSequentialReleaseStaysPressedUntilIdle() {
        var engagement = ModifierChordEngagement()
        XCTAssertFalse(engagement.isPressed(commandOption(command: true, option: false)))
        XCTAssertTrue(engagement.isPressed(commandOption(command: true, option: true)))
        XCTAssertTrue(engagement.isPressed(commandOption(command: true, option: false)))
        XCTAssertFalse(engagement.isPressed(commandOption(command: false, option: false)))
    }

    func testCommandOnlyDoubleTapDoesNotToggleACommandOptionShortcut() {
        var engagement = ModifierChordEngagement()
        var detector = ModifierDoubleTapDetector()

        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: true, option: false)),
            now: 0
        ))
        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: false, option: false)),
            now: 0.1
        ))
        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: true, option: false)),
            now: 0.2
        ))
    }

    func testFullChordDoubleTapStillFiresWhenKeysReleaseOneAtATime() {
        var engagement = ModifierChordEngagement()
        var detector = ModifierDoubleTapDetector()

        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: true, option: false)),
            now: 0
        ))
        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: true, option: true)),
            now: 0.02
        ))
        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: true, option: false)),
            now: 0.08
        ))
        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: false, option: false)),
            now: 0.12
        ))
        XCTAssertFalse(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: true, option: false)),
            now: 0.20
        ))
        XCTAssertTrue(detector.modifierChanged(
            active: engagement.isPressed(commandOption(command: true, option: true)),
            now: 0.24
        ))
    }

    func testOptionOnlyToggleStillFiresOnAShortTap() {
        var engagement = ModifierChordEngagement()
        var detector = ModifierToggleTapDetector()
        let optionDown = ModifierBindingState(
            bindingCommand: false,
            bindingOption: true,
            bindingControl: false,
            bindingShift: false,
            command: false,
            option: true,
            control: false,
            shift: false
        )
        let idle = ModifierBindingState(
            bindingCommand: false,
            bindingOption: true,
            bindingControl: false,
            bindingShift: false,
            command: false,
            option: false,
            control: false,
            shift: false
        )

        XCTAssertFalse(detector.modifierChanged(active: engagement.isPressed(optionDown), now: 0))
        XCTAssertTrue(detector.modifierChanged(active: engagement.isPressed(idle), now: 0.1))
    }

    func testResetClearsALatchedFullChord() {
        var engagement = ModifierChordEngagement()
        XCTAssertTrue(engagement.isPressed(commandOption(command: true, option: true)))
        engagement.reset()
        XCTAssertFalse(engagement.isPressed(commandOption(command: true, option: false)))
    }
}
