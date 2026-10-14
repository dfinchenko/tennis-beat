@testable import TennisBeat_Watch_App

/// Records haptic requests in order.
final class RecordingHaptics: HapticPlaying {
  enum Call: Equatable {
    case play(PointOutcome)
    case cancelPending
    case flushPending
  }

  private(set) var calls: [Call] = []

  /// The patterns the requests would play, in order (contract §4).
  var haptics: [Haptic] {
    calls.flatMap { call -> [Haptic] in
      if case .play(let outcome) = call { Haptic.sequence(for: outcome) } else { [] }
    }
  }

  func play(_ outcome: PointOutcome) { calls.append(.play(outcome)) }
  func cancelPending() { calls.append(.cancelPending) }
  func flushPending() { calls.append(.flushPending) }

  func reset() { calls = [] }
}
