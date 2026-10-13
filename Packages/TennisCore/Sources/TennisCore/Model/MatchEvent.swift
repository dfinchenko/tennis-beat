import Foundation

/// One entry of a match record (FR-001).
public enum MatchEvent: Sendable, Hashable {
  /// The format and the first server. Exactly one, always first.
  case setup(MatchSetup)
  /// A point won by `winner`. `recordedAt` is stored and restored but never used for state (FR-032).
  case point(winner: Player, recordedAt: Date)
  /// The players stopped before the match was decided [ITF: MT-08].
  case matchEndedEarly
  /// The player who really served first [ITF: CE-02].
  case firstServerCorrected(Player)
}
