/// A player's point score. The apps turn it into localized text (research R7).
public enum PointDisplay: Sendable, Hashable {
  case zero
  case fifteen
  case thirty
  case forty
  case advantage
  /// Points in a tie-break or match tie-break.
  case tieBreak(Int)
}

/// The half of the court the server serves from [ITF: SV-03, TB-04, NA-02].
public enum CourtSide: Sendable, Hashable {
  case right
  case left
  /// The No-Ad deciding point: the receiver chooses.
  case receiversChoice
}

/// Whether the match is still being played (FR-013, FR-029).
public enum MatchStatus: Sendable, Hashable {
  case inProgress
  case won(Player)
  /// Ended early, with no winner [ITF: MT-08].
  case unfinished
}

/// A completed set. A match tie-break is recorded as a set won 1–0 [ITF: MT-05].
public struct SetScore: Sendable, Hashable {
  public let games: PlayerPair<Int>
  /// The tie-break's point score, if the set was decided by one.
  public let tieBreak: PlayerPair<Int>?
  public let isMatchTieBreak: Bool
  public let winner: Player
}

/// Everything the engine exposes after each event (FR-014).
public struct MatchState: Sendable, Hashable {
  public let status: MatchStatus
  public let completedSets: [SetScore]
  /// Games in the current set; 0–0 once the match is won.
  public let games: PlayerPair<Int>
  public let points: PlayerPair<PointDisplay>
  public let server: Player
  public let courtSide: CourtSide
  public let isDeuce: Bool
  public let isDecidingPoint: Bool
  public let isTieBreak: Bool
  public let isMatchTieBreak: Bool
  /// The most recent point's change-of-ends value; `false` before the first point.
  public let changeOfEnds: Bool
}
