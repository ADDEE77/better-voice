public enum RecordingShortcutAction: Equatable {
    case schedulePushToTalk
    case cancelPendingPushToTalk
    case startPushToTalk
    case stopPushToTalk
    case toggleLongForm
    case promoteToLongForm
}

public enum RecordingModifier: String, CaseIterable, Equatable, Hashable, Sendable {
    case option
    case command
    case control
    case shift

    public var name: String {
        switch self {
        case .option: return "Option"
        case .command: return "Command"
        case .control: return "Control"
        case .shift: return "Shift"
        }
    }

    public var symbol: String {
        switch self {
        case .option: return "⌥"
        case .command: return "⌘"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }
}

public enum RecordingLongShortcut: String, CaseIterable, Equatable, Hashable, Sendable {
    case commandOption
    case commandShift
    case optionShift
    case controlOption

    public var name: String {
        switch self {
        case .commandOption: return "Command + Option"
        case .commandShift: return "Command + Shift"
        case .optionShift: return "Option + Shift"
        case .controlOption: return "Control + Option"
        }
    }

    public var label: String {
        switch self {
        case .commandOption: return "⌘⌥"
        case .commandShift: return "⌘⇧"
        case .optionShift: return "⌥⇧"
        case .controlOption: return "⌃⌥"
        }
    }

    fileprivate var modifiers: Set<RecordingModifier> {
        switch self {
        case .commandOption: return [.command, .option]
        case .commandShift: return [.command, .shift]
        case .optionShift: return [.option, .shift]
        case .controlOption: return [.control, .option]
        }
    }
}

public struct RecordingShortcutConfiguration: Equatable, Sendable {
    public var quickModifier: RecordingModifier
    public var longShortcut: RecordingLongShortcut

    public static let standard = RecordingShortcutConfiguration(
        quickModifier: .option,
        longShortcut: .commandOption
    )

    public init(
        quickModifier: RecordingModifier = .option,
        longShortcut: RecordingLongShortcut = .commandOption
    ) {
        self.quickModifier = quickModifier
        self.longShortcut = longShortcut
    }

    public func activeStates(
        command: Bool,
        option: Bool,
        control: Bool,
        shift: Bool
    ) -> (quick: Bool, long: Bool, other: Bool) {
        let active: Set<RecordingModifier> = Set([
            command ? .command : nil,
            option ? .option : nil,
            control ? .control : nil,
            shift ? .shift : nil
        ].compactMap { $0 })
        let recognized = longShortcut.modifiers.union([quickModifier])
        return (
            active.contains(quickModifier),
            longShortcut.modifiers.isSubset(of: active),
            !active.subtracting(recognized).isEmpty
        )
    }
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
        process(
            quickActive: option,
            longActive: command && option,
            otherModifier: otherModifier
        )
    }

    public mutating func flagsChanged(
        quickActive: Bool,
        longActive: Bool,
        otherModifier: Bool = false
    ) -> [RecordingShortcutAction] {
        process(
            quickActive: quickActive,
            longActive: longActive,
            otherModifier: otherModifier
        )
    }

    private mutating func process(
        quickActive: Bool,
        longActive: Bool,
        otherModifier: Bool
    ) -> [RecordingShortcutAction] {
        if mode == .pushToTalk, otherModifier {
            guard !quickActive else { return [] }
            mode = .idle
            return [.stopPushToTalk]
        }
        if mode == .pendingPushToTalk, otherModifier {
            mode = .idle
            return [.cancelPendingPushToTalk]
        }
        guard !otherModifier else { return [] }
        if longActive {
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
        if !quickActive, mode == .suppressUntilOptionRelease {
            mode = .idle
            return []
        }
        if quickActive, mode == .idle {
            mode = .pendingPushToTalk
            return [.schedulePushToTalk]
        }
        if !quickActive, mode == .pushToTalk {
            mode = .idle
            return [.stopPushToTalk]
        }
        if !quickActive, mode == .pendingPushToTalk {
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
