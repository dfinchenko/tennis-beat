/// Everything derived from a match record: the cached value behind `Match.state` and `Match.stats`.
struct Reduction: Sendable, Hashable {
  var score: ScoreTrack
  var service: ServiceTrack
  var stats: MatchStats = .zero
  var endedEarly = false

  var status: MatchStatus {
    if let winner = score.winner { return .won(winner) }
    return endedEarly ? .unfinished : .inProgress
  }

  var state: MatchState {
    MatchState(
      status: status,
      completedSets: score.completedSets,
      games: score.games,
      points: score.pointDisplays,
      server: service.server(in: score),
      courtSide: service.courtSide(in: score),
      isDeuce: score.isDeuce,
      isDecidingPoint: score.isDecidingPoint,
      isTieBreak: score.mode != .standard,
      isMatchTieBreak: score.mode == .matchTieBreak,
      changeOfEnds: score.changeOfEnds
    )
  }
}

/// What one point meant, for stats.
struct PointContext: Sendable, Hashable {
  var winner: Player
  var server: Player
  /// A standard-game point the receiver wins the game with if they win it [ITF: BP-01, BP-02].
  var isBreakPoint: Bool
  var outcome: ScoreTrack.Outcome
}

/// The pure reduction of a match record (research R1, R2).
enum Reducer {
  static func initial(setup: MatchSetup, effectiveFirstServer: Player) -> Reduction {
    Reduction(
      score: ScoreTrack(format: setup.format),
      service: ServiceTrack(firstServer: effectiveFirstServer))
  }

  /// Applies one point. The caller has checked that the match is in progress.
  @discardableResult
  static func step(_ reduction: inout Reduction, winner: Player) -> PointContext {
    let score = reduction.score
    let server = reduction.service.server(in: score)
    let receiver = server.other
    var ifReceiverWins = score.points
    ifReceiverWins[receiver] += 1
    let isBreakPoint = score.mode == .standard && score.winsGame(receiver, with: ifReceiverWins)

    let outcome = reduction.score.addPoint(winner)
    reduction.service.pointPlayed(outcome)
    let context = PointContext(
      winner: winner, server: server, isBreakPoint: isBreakPoint, outcome: outcome)
    reduction.stats.add(context)
    return context
  }

  /// Rebuilds the reduction of `events` from scratch, ignoring setup and recorded times.
  static func replay(setup: MatchSetup, effectiveFirstServer: Player, events: [MatchEvent])
    -> Reduction
  {
    var reduction = initial(setup: setup, effectiveFirstServer: effectiveFirstServer)
    for event in events {
      switch event {
      case .point(let winner, _): step(&reduction, winner: winner)
      case .setup, .matchEndedEarly, .firstServerCorrected: break
      }
    }
    return reduction
  }
}
