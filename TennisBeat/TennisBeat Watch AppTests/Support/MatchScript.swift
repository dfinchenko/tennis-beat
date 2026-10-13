import Foundation
import TennisCore
import Testing

/// Test DSL for building engine matches, like TennisCore's `MatchBuilder`.
///
/// `play("MMOM")`: `M` = Me won the point, `O` = Opponent won it; spaces are ignored.
enum MatchScript {
  static func match(
    _ format: MatchFormat, firstServer: Player = .me, points: String = "",
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> Match {
    var match = Match(setup: MatchSetup(format: format, firstServer: firstServer))
    play(points, on: &match, sourceLocation: sourceLocation)
    return match
  }

  static func play(
    _ points: String, on match: inout Match, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    for character in points where character != " " {
      let winner: Player
      switch character {
      case "M": winner = .me
      case "O": winner = .opponent
      default:
        Issue.record("unknown point '\(character)'", sourceLocation: sourceLocation)
        continue
      }
      do {
        try match.recordPoint(
          wonBy: winner, at: Date(timeIntervalSinceReferenceDate: Double(match.events.count)))
      } catch {
        Issue.record("point for \(winner) rejected: \(error)", sourceLocation: sourceLocation)
      }
    }
  }

  /// Points that win `count` straight games for `player` from the start of a game.
  static func games(_ count: Int, for player: Player) -> String {
    String(repeating: player == .me ? "MMMM" : "OOOO", count: count)
  }

  /// Points that win a set N–0 for `player`.
  static func set(_ format: MatchFormat, for player: Player) -> String {
    games(format.setLength.rawValue, for: player)
  }
}
