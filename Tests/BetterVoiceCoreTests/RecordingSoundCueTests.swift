import XCTest
@testable import BetterVoiceCore

final class RecordingSoundCueTests: XCTestCase {
    func testListeningAndFinishedCuesAreDistinctSystemSounds() {
        XCTAssertNotEqual(
            RecordingSoundCue.started.systemSoundName,
            RecordingSoundCue.finished.systemSoundName
        )
    }
}
