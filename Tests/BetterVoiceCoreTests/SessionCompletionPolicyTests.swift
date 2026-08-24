import XCTest
@testable import BetterVoiceCore

final class SessionCompletionPolicyTests: XCTestCase {
    func testShortEmptySessionIsDiscardedAsAnAccidentalShortcut() {
        XCTAssertEqual(
            sessionCompletionDisposition(hasTranscript: false, hasContext: false, duration: 1.2),
            .discardAccidental
        )
    }

    func testLongEmptySessionIsKeptWithoutBeingAnError() {
        XCTAssertEqual(
            sessionCompletionDisposition(hasTranscript: false, hasContext: false, duration: 4),
            .saveEmpty
        )
    }

    func testTranscriptOrContextIsDelivered() {
        XCTAssertEqual(
            sessionCompletionDisposition(hasTranscript: true, hasContext: false, duration: 0.2),
            .deliver
        )
        XCTAssertEqual(
            sessionCompletionDisposition(hasTranscript: false, hasContext: true, duration: 0.2),
            .deliver
        )
    }
}
