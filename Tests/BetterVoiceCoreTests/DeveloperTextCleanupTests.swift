import XCTest
@testable import BetterVoiceCore

final class DeveloperTextCleanupTests: XCTestCase {
    func testCommonTermsUseDeveloperCasing() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("use github with a javascript api and json"),
            "use GitHub with a JavaScript API and JSON"
        )
    }

    func testTerminalProfileCollapsesSpokenAcronyms() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("run n p m install then inspect the j s o n", profile: .terminal),
            "run npm install then inspect the JSON"
        )
    }

    func testGeneralProfileKeepsSpokenAcronyms() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("a p i access", profile: .general),
            "a p i access"
        )
    }

    func testPunctuationAndWordingStayUntouched() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("Please use SwiftUI, not Swift."),
            "Please use SwiftUI, not Swift."
        )
    }
}
