import Foundation

/// Elapsed match time (data-model.md § MatchClock, research R5).
///
/// Wall-clock time since the start, so it stays right after the app returns from the
/// background. Pause and reopen arrive with Controls and Summary.
nonisolated struct MatchClock: Hashable, Sendable {
  let startedAt: Date
  /// When the match was won or ended early.
  private(set) var stoppedAt: Date?

  init(startedAt: Date) {
    self.startedAt = startedAt
  }

  /// Freezes the time; a second stop keeps the first.
  mutating func stop(at date: Date) {
    if stoppedAt == nil { stoppedAt = date }
  }

  /// Never negative, and fixed once stopped.
  func elapsed(at date: Date) -> TimeInterval {
    max(0, (stoppedAt ?? date).timeIntervalSince(startedAt))
  }
}
