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

    func testGeneralProfileDoesNotUppercaseOrdinaryWords() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("take a rest and whisper to the parakeet"),
            "take a rest and whisper to the parakeet"
        )
    }

    func testDeveloperProfilePreservesFileExtensions() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("run cat package.json", profile: .terminal),
            "run cat package.json"
        )
    }

    func testPunctuationAndWordingStayUntouched() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("Please use SwiftUI, not Swift."),
            "Please use SwiftUI, not Swift."
        )
    }

    func testUserTermsAreApplied() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("deploy with cube cuttle", overrides: [("cube cuttle", "kubectl")]),
            "deploy with kubectl"
        )
    }

    func testUserTermsRunFirstSoTheBuiltInCasingStillSeesThem() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("push it to get hub", overrides: [("get hub", "github")]),
            "push it to GitHub"
        )
    }

    func testAUserTermOverridesTheBuiltInSpellingForTheSameSource() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("read the json", overrides: [("json", "Json")]),
            "read the Json"
        )
    }

    func testUserTermsKeepTheWholeWordAndPathProtections() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("open src/psequel/main.go", overrides: [("psequel", "psql")]),
            "open src/psequel/main.go"
        )
    }

    func testAccentedWordsThatBeginWithATermAreLeftAlone() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("o apiário fica no sítio"),
            "o apiário fica no sítio"
        )
    }

    func testTermsNextToAccentedWordsAreStillCased() {
        XCTAssertEqual(
            DeveloperTextCleanup.apply("a última resposta é json"),
            "a última resposta é JSON"
        )
    }
}
