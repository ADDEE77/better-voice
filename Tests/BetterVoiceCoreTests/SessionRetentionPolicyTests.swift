import Foundation
import XCTest
@testable import BetterVoiceCore

final class SessionRetentionPolicyTests: XCTestCase {
    func testRemovesExpiredThenOldestSessionsUntilUnderSizeLimit() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let day: TimeInterval = 86_400
        let policy = SessionRetentionPolicy(maxAge: 7 * day, maxBytes: 500)
        let sessions = [
            StoredSession(name: "expired", modifiedAt: now.addingTimeInterval(-8 * day), bytes: 100),
            StoredSession(name: "oldest", modifiedAt: now.addingTimeInterval(-3 * day), bytes: 300),
            StoredSession(name: "newest", modifiedAt: now.addingTimeInterval(-day), bytes: 300)
        ]

        XCTAssertEqual(policy.sessionsToRemove(from: sessions, now: now), ["expired", "oldest"])
    }

    func testRejectsAFileThatWouldExceedTheStorageLimit() {
        let policy = SessionRetentionPolicy(maxAge: 1, maxBytes: 500)

        XCTAssertTrue(policy.canStore(additionalBytes: 100, usedBytes: 400))
        XCTAssertFalse(policy.canStore(additionalBytes: 101, usedBytes: 400))
    }

    func testOnlyRecognizesGeneratedSessionFolderNames() {
        XCTAssertTrue(isBetterVoiceSessionName(
            "2026-08-23T15-16-45Z-C81A6E98-FD94-4FC6-AF2C-8928EBD938B1"
        ))
        XCTAssertFalse(isBetterVoiceSessionName("my-important-folder"))
        XCTAssertFalse(isBetterVoiceSessionName("backup-C81A6E98-FD94-4FC6-AF2C-8928EBD938B1"))
    }
}
