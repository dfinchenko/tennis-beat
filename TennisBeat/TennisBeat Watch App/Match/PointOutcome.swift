import TennisCore

/// The FR-010 result of one added point (data-model.md § PointOutcome, research R2).
///
/// Derived only by comparing the engine's state before and after the point; the app keeps no
/// score logic of its own. Haptics and announcements use nothing else.
nonisolated struct PointOutcome: Hashable, Sendable {
  enum Level: Hashable, Sendable { case point, game, set, match }

  let winner: Player
  let level: Level
  let changeOfEnds: Bool

  /// Call only after `recordPoint` succeeded. A set reset puts `games` back to 0–0, so the
  /// set check comes before the game check.
  static func evaluate(before: MatchState, after: MatchState, winner: Player) -> PointOutcome {
    let level: Level
    if before.status == .inProgress, case .won = after.status {
      level = .match
    } else if after.completedSets.count > before.completedSets.count {
      level = .set
    } else if after.games.me + after.games.opponent > before.games.me + before.games.opponent {
      level = .game
    } else {
      level = .point
    }
    // ITF: EN-05 — never after the match-winning point.
    return PointOutcome(
      winner: winner, level: level, changeOfEnds: after.changeOfEnds && level != .match)
  }
}
