import Foundation

public enum SessionCompletionDisposition: Equatable {
    case discardAccidental
    case saveEmpty
    case deliver
}

public func sessionCompletionDisposition(
    hasTranscript: Bool,
    hasContext: Bool,
    duration: TimeInterval,
    accidentalThreshold: TimeInterval = 2.5
) -> SessionCompletionDisposition {
    guard !hasTranscript && !hasContext else { return .deliver }
    return duration < accidentalThreshold ? .discardAccidental : .saveEmpty
}
