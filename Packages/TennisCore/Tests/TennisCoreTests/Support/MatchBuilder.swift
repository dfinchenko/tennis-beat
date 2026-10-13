import Foundation
import Testing

@testable import TennisCore

/// Test DSL for building matches (T012).
///
/// `play("MMOM …")`: `M` = Me won the point, `O` = Opponent won it; spaces are ignored.
/// Every point is recorded one second after the previous event, so `recordedAt` is deterministic.
extension Match {
  static func make(
    _ length: MatchLength = .bestOfThree,
    setLength: SetLength = .six,
    scoring: GameScoring = .advantage,
    matchTieBreak: Bool = false,
    firstServer: Player = .me
  ) throws -> Match {
    let format = try MatchFormat(
      length: length, setLength: setLength, gameScoring: scoring, matchTieBreak: matchTieBreak)
    return Match(setup: MatchSetup(format: format, firstServer: firstServer))
  }

  /// The time the builder records the next point at.
  var nextTime: Date { Date(timeIntervalSinceReferenceDate: 800_000_000 + Double(events.count)) }

  /// Records one point; a rejection is reported as a test issue, never a trap.
  mutating func point(_ winner: Player, sourceLocation: SourceLocation = #_sourceLocation) {
    do {
      try recordPoint(wonBy: winner, at: nextTime)
    } catch {
      Issue.record("point for \(winner) rejected: \(error)", sourceLocation: sourceLocation)
    }
  }

  mutating func play(_ points: String, sourceLocation: SourceLocation = #_sourceLocation) {
    for character in points where character != " " {
      switch character {
      case "M": point(.me, sourceLocation: sourceLocation)
      case "O": point(.opponent, sourceLocation: sourceLocation)
      default: Issue.record("unknown point '\(character)'", sourceLocation: sourceLocation)
      }
    }
  }

  /// Four straight points: wins a standard game from 0–0.
  mutating func winGame(_ player: Player, sourceLocation: SourceLocation = #_sourceLocation) {
    for _ in 0..<4 { point(player, sourceLocation: sourceLocation) }
  }

  /// Wins standard games from the current game score, alternating so the set is never
  /// decided before the last game (the player with more games wins first).
  mutating func winGames(me: Int, opponent: Int, sourceLocation: SourceLocation = #_sourceLocation)
  {
    var left = PlayerPair(me: me, opponent: opponent)
    var next: Player = me >= opponent ? .me : .opponent
    while left.me + left.opponent > 0 {
      if left[next] == 0 { next = next.other }
      winGame(next, sourceLocation: sourceLocation)
      left[next] -= 1
      next = next.other
    }
  }

  /// Seven straight points: wins a tie-break from 0–0.
  mutating func winTieBreak(_ player: Player, sourceLocation: SourceLocation = #_sourceLocation) {
    for _ in 0..<7 { point(player, sourceLocation: sourceLocation) }
  }

  /// Wins a set N–0 from 0–0.
  mutating func winSet(_ player: Player, sourceLocation: SourceLocation = #_sourceLocation) {
    let n = setup.format.setLength.rawValue
    winGames(
      me: player == .me ? n : 0, opponent: player == .me ? 0 : n, sourceLocation: sourceLocation)
  }

  /// Reaches N–N from 0–0, so the next game is a tie-break.
  mutating func reachTieBreak(sourceLocation: SourceLocation = #_sourceLocation) {
    let n = setup.format.setLength.rawValue
    winGames(me: n, opponent: n, sourceLocation: sourceLocation)
  }

  var pointCount: Int {
    events.reduce(0) { count, event in
      if case .point = event { return count + 1 }
      return count
    }
  }
}

/// Shorthand for point displays in expectations.
func pts(_ me: PointDisplay, _ opponent: PointDisplay) -> PlayerPair<PointDisplay> {
  PlayerPair(me: me, opponent: opponent)
}

func pair(_ me: Int, _ opponent: Int) -> PlayerPair<Int> {
  PlayerPair(me: me, opponent: opponent)
}
