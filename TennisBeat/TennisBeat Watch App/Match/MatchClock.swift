import Foundation

/// Elapsed match time (data-model.md § MatchClock, research R5).
///
/// Wall-clock time since the start minus pauses, so it stays right after the app returns
/// from the background. Reopening after the summary arrives with the Summary (PR 4).
nonisolated struct MatchClock: Hashable, Sendable {
  let startedAt: Date
  /// Closed pauses.
  private(set) var excluded: [DateInterval] = []
  /// Start of the open pause.
  private(set) var pausedAt: Date?
  /// When the match was won or ended early.
  private(set) var stoppedAt: Date?

  init(startedAt: Date) {
    self.startedAt = startedAt
  }

  var isPaused: Bool { pausedAt != nil }

  /// Opens a pause; nothing happens when already paused or stopped.
  mutating func pause(at date: Date) {
    guard pausedAt == nil, stoppedAt == nil else { return }
    pausedAt = date
  }

  /// Closes the open pause.
  mutating func resume(at date: Date) {
    guard let pausedAt else { return }
    excluded.append(DateInterval(start: pausedAt, end: max(date, pausedAt)))
    self.pausedAt = nil
  }

  /// Freezes the time, closing an open pause first; a second stop keeps the first.
  mutating func stop(at date: Date) {
    guard stoppedAt == nil else { return }
    resume(at: date)
    stoppedAt = date
  }

  /// Never negative; fixed while paused or stopped.
  func elapsed(at date: Date) -> TimeInterval {
    let end = stoppedAt ?? pausedAt ?? date
    let paused = excluded.reduce(0) { $0 + $1.duration }
    return max(0, end.timeIntervalSince(startedAt) - paused)
  }
}
