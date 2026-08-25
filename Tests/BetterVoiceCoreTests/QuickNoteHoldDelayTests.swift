import XCTest
@testable import BetterVoiceCore

final class QuickNoteHoldDelayTests: XCTestCase {
    func testClampKeepsDefault() {
        XCTAssertEqual(QuickNoteHoldDelay.clamp(140), 140)
    }

    func testClampFloorsLowValues() {
        XCTAssertEqual(QuickNoteHoldDelay.clamp(10), QuickNoteHoldDelay.minimumMilliseconds)
    }

    func testClampCapsHighValues() {
        XCTAssertEqual(QuickNoteHoldDelay.clamp(900), QuickNoteHoldDelay.maximumMilliseconds)
    }

    func testHoldDetailIncludesMilliseconds() {
        XCTAssertTrue(
            QuickNoteTriggerMode.hold.detail(holdDelayMilliseconds: 200).contains("200 ms")
        )
    }
}
