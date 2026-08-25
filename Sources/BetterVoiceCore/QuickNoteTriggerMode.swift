import Foundation

/// How the quick-note shortcut starts and stops recording.
public enum QuickNoteTriggerMode: String, Sendable, CaseIterable {
    /// Press and hold the shortcut; release to finish.
    case hold
    /// Tap the modifier twice quickly to start; tap twice again to stop.
    case doubleTap

    public var name: String {
        switch self {
        case .hold: return "Hold to record"
        case .doubleTap: return "Double-tap to toggle"
        }
    }

    public var detail: String {
        switch self {
        case .hold:
            return "Hold this shortcut to record. Release it to finish."
        case .doubleTap:
            return "Double-tap this shortcut to start. Double-tap again to finish."
        }
    }
}

/// Detects a double-tap on a lone modifier key without treating holds or
/// modifier+key combos as taps.
public struct ModifierDoubleTapDetector: Sendable {
  public static let maxTapDuration: TimeInterval = 0.25
  public static let doubleTapInterval: TimeInterval = 0.40

  private var modifierPressed = false
  private var modifierDownAt: TimeInterval?
  private var firstTapReleasedAt: TimeInterval?
  private var comboInterrupted = false

  public init() {}

  public mutating func reset() {
    modifierPressed = false
    modifierDownAt = nil
    firstTapReleasedAt = nil
    comboInterrupted = false
  }

  /// Call when any non-modifier key goes down while the quick modifier may be held.
  public mutating func nonModifierKeyPressed() {
    comboInterrupted = true
    firstTapReleasedAt = nil
  }

  /// Returns `true` when a completed double-tap should toggle recording.
  public mutating func modifierChanged(active: Bool, now: TimeInterval) -> Bool {
    if active {
      if let armedAt = firstTapReleasedAt {
        if now - armedAt <= Self.doubleTapInterval {
          reset()
          modifierPressed = true
          modifierDownAt = now
          return true
        }
        firstTapReleasedAt = nil
      }
      comboInterrupted = false
      modifierPressed = true
      modifierDownAt = now
      return false
    }

    guard modifierPressed else { return false }
    modifierPressed = false
    let downAt = modifierDownAt
    modifierDownAt = nil

    guard let downAt else { return false }
    let held = now - downAt
    guard !comboInterrupted, held <= Self.maxTapDuration else {
      firstTapReleasedAt = nil
      comboInterrupted = false
      return false
    }

    firstTapReleasedAt = now
    return false
  }
}
