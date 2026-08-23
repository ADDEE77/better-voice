import Foundation

public func isBetterVoiceSessionName(_ name: String) -> Bool {
    name.range(
        of: #"^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z-[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$"#,
        options: .regularExpression
    ) != nil
}

public struct StoredSession: Equatable {
    public let name: String
    public let modifiedAt: Date
    public let bytes: Int64

    public init(name: String, modifiedAt: Date, bytes: Int64) {
        self.name = name
        self.modifiedAt = modifiedAt
        self.bytes = bytes
    }
}

public struct SessionRetentionPolicy {
    public let maxAge: TimeInterval
    public let maxBytes: Int64

    public init(maxAge: TimeInterval, maxBytes: Int64) {
        self.maxAge = maxAge
        self.maxBytes = maxBytes
    }

    public func canStore(additionalBytes: Int64, usedBytes: Int64) -> Bool {
        additionalBytes >= 0 && usedBytes >= 0 && additionalBytes <= maxBytes - usedBytes
    }

    public func sessionsToRemove(from sessions: [StoredSession], now: Date) -> Set<String> {
        var removed = Set(sessions.filter { now.timeIntervalSince($0.modifiedAt) > maxAge }.map(\.name))
        let kept = sessions.filter { !removed.contains($0.name) }
        var bytes = kept.reduce(0) { $0 + $1.bytes }

        for session in kept.sorted(by: { $0.modifiedAt < $1.modifiedAt }) where bytes > maxBytes {
            removed.insert(session.name)
            bytes -= session.bytes
        }
        return removed
    }
}
