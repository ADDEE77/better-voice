import XCTest
@testable import BetterVoiceCore

final class TranscriptionLanguageTests: XCTestCase {
    func testDefaultsToEnglishWhenNothingIsStored() {
        XCTAssertEqual(TranscriptionLanguage(storedCode: nil), .english)
    }

    func testFallsBackToEnglishWhenTheStoredCodeIsUnknown() {
        XCTAssertEqual(TranscriptionLanguage(storedCode: "klingon"), .english)
    }

    func testRestoresEveryOfferedLanguageFromItsStoredCode() {
        for language in TranscriptionLanguage.all {
            XCTAssertEqual(TranscriptionLanguage(storedCode: language.code), language)
        }
    }

    func testEnglishStaysOnTheEnglishOnlyModel() {
        XCTAssertTrue(TranscriptionLanguage.english.usesEnglishOnlyModel)
    }

    func testEveryOtherLanguageNeedsTheMultilingualModel() {
        for language in TranscriptionLanguage.all where language != .english {
            XCTAssertFalse(
                language.usesEnglishOnlyModel,
                "\(language.code) cannot be served by the English-only model"
            )
        }
    }

    func testOnlyEnglishAllowsTheEnglishOnlyGrammarModel() {
        XCTAssertTrue(TranscriptionLanguage.english.allowsGrammarCorrection)
        for language in TranscriptionLanguage.all where language != .english {
            XCTAssertFalse(language.allowsGrammarCorrection, "\(language.code)")
        }
    }

    func testAutomaticCarriesNoScriptHint() {
        XCTAssertNil(TranscriptionLanguage.automatic.scriptHintCode)
        XCTAssertEqual(TranscriptionLanguage.english.scriptHintCode, "en")
    }

    func testCodesAreUniqueAndNamesAreNotEmpty() {
        XCTAssertEqual(Set(TranscriptionLanguage.all.map(\.code)).count, TranscriptionLanguage.all.count)
        for language in TranscriptionLanguage.all {
            XCTAssertFalse(language.name.isEmpty, language.code)
        }
    }
}
