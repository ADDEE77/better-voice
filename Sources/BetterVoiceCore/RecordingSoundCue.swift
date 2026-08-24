public enum RecordingSoundCue: Equatable {
    case started
    case finished

    public var systemSoundName: String {
        switch self {
        case .started: "Purr"
        case .finished: "Pop"
        }
    }
}
