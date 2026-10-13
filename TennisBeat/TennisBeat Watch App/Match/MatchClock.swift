import Foundation

/// Elapsed match time (data-model.md § MatchClock, research R5).
///
/// Wall-clock time since the start, so it stays right after the app returns from the
/// background. Pause, stop and reopen arrive with the score screen, Controls and Summary.
nonisolated struct MatchClock: Hashable, Sendable {
  let startedAt: Date

  /// Never negative.
  func elapsed(at date: Date) -> TimeInterval {
    max(0, date.timeIntervalSince(startedAt))
  }
}
