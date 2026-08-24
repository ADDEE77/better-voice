import XCTest
@testable import BetterVoiceCore

final class RecordingSoundCueTests: XCTestCase {
    func testListeningUsesTheSofterPurrCue() {
        XCTAssertEqual(RecordingSoundCue.started.systemSoundName, "Purr")
    }

    func testListeningAndFinishedCuesAreDistinctSystemSounds() {
        XCTAssertNotEqual(
            RecordingSoundCue.started.systemSoundName,
            RecordingSoundCue.finished.systemSoundName
        )
    }
}
