/// Who serves, built on the score track from the effective first server (research R1).
struct ServiceTrack: Sendable, Hashable {
  /// The server of the first point of the current game, tie-break or match tie-break.
  private(set) var gameServer: Player

  init(firstServer: Player) {
    gameServer = firstServer  // ITF: SV-01
  }

  /// The server of the next point.
  func server(in score: ScoreTrack) -> Player {
    guard score.mode != .standard else { return gameServer }
    // ITF: TB-02 — point k (0-based): the first server serves k = 0, then two points each.
    let k = score.pointsPlayedInGame
    return ((k + 1) / 2).isMultiple(of: 2) ? gameServer : gameServer.other
  }

  /// The side the next point is served from.
  func courtSide(in score: ScoreTrack) -> CourtSide {
    if score.isDecidingPoint { return .receiversChoice }  // ITF: NA-02
    // ITF: SV-03, TB-04 — right when the points already played are even.
    return score.pointsPlayedInGame.isMultiple(of: 2) ? .right : .left
  }

  mutating func pointPlayed(_ outcome: ScoreTrack.Outcome) {
    guard outcome.gameEnded else { return }
    // ITF: SV-02 — after a standard game the receiver serves next.
    // ITF: TB-03, SV-04, MT-04 — after a tie-break, the tie-break's first receiver serves next.
    // Both are the other player of the finished game's first server.
    gameServer = gameServer.other
  }
}
