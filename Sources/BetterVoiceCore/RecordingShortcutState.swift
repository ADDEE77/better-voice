public enum RecordingShortcutAction: Equatable {
    case schedulePushToTalk
    case cancelPendingPushToTalk
    case startPushToTalk
    case stopPushToTalk
    case toggleLongForm
    case promoteToLongForm
}

public struct RecordingShortcutState {
    private enum Mode {
        case idle
        case pendingPushToTalk
        case pushToTalk
        case suppressUntilOptionRelease
    }

    private var mode = Mode.idle

    public init() {}

    public mutating func flagsChanged(
        command: Bool,
        option: Bool,
        otherModifier: Bool = false
    ) -> [RecordingShortcutAction] {
        if mode == .pushToTalk, otherModifier {
            guard !option else { return [] }
            mode = .idle
            return [.stopPushToTalk]
        }
        if mode == .pendingPushToTalk, otherModifier {
            mode = .idle
            return [.cancelPendingPushToTalk]
        }
        guard !otherModifier else { return [] }
        if command, option {
            switch mode {
            case .idle:
                mode = .suppressUntilOptionRelease
                return [.toggleLongForm]
            case .pendingPushToTalk:
                mode = .suppressUntilOptionRelease
                return [.cancelPendingPushToTalk, .toggleLongForm]
            case .pushToTalk:
                mode = .suppressUntilOptionRelease
                return [.promoteToLongForm]
            case .suppressUntilOptionRelease:
                return []
            }
        }
        if !option, mode == .suppressUntilOptionRelease {
            mode = .idle
            return []
        }
        guard !command else { return [] }
        if option, mode == .idle {
            mode = .pendingPushToTalk
            return [.schedulePushToTalk]
        }
        if !option, mode == .pushToTalk {
            mode = .idle
            return [.stopPushToTalk]
        }
        if !option, mode == .pendingPushToTalk {
            mode = .idle
            return [.cancelPendingPushToTalk]
        }
        return []
    }

    public mutating func pushToTalkDelayElapsed() -> [RecordingShortcutAction] {
        guard mode == .pendingPushToTalk else { return [] }
        mode = .pushToTalk
        return [.startPushToTalk]
    }
}
