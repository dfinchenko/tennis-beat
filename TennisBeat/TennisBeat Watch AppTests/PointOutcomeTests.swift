import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// FR-010, FR-011, research R2: the outcome of one added point, from the engine states
/// before and after it. Every state is built with the engine (`MatchScript`).
@MainActor
struct PointOutcomeTests {
  static func format(
    _ length: MatchLength = .bestOfThree, _ setLength: SetLength = .six,
    _ scoring: GameScoring = .advantage, matchTieBreak: Bool = false
  ) -> MatchFormat {
    // Every format used here is valid (MT-02 holds), so the init can't throw.
    try! MatchFormat(
      length: length, setLength: setLength, gameScoring: scoring, matchTieBreak: matchTieBreak)
  }

  /// Plays `setup`, then `last` (one point), and evaluates that last point.
  private func outcome(
    _ format: MatchFormat, _ setup: String, last: Character,
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> PointOutcome {
    var match = MatchScript.match(format, points: setup, sourceLocation: sourceLocation)
    let before = match.state
    MatchScript.play(String(last), on: &match, sourceLocation: sourceLocation)
    let winner: Player = last == "M" ? .me : .opponent
    return PointOutcome.evaluate(before: before, after: match.state, winner: winner)
  }

  private let g = MatchScript.games
  /// Set 1 won 6–0 by Me, set 2 won 6–0 by Opponent: a match tie-break follows (MT-03).
  private var toMatchTieBreak: String { g(6, .me) + g(6, .opponent) }

  // MARK: Levels

  @Test("US3 s4 a point that wins no game is a point")
  func pointLevel() {
    let result = outcome(Self.format(), "", last: "M")
    #expect(result == PointOutcome(winner: .me, level: .point, changeOfEnds: false))
  }

  @Test("US3 s1 a game won in an Advantage game, not the set, is a game")  // ITF: GM-02
  func gameAfterAdvantage() {
    // Game 2 (even, no change of ends): deuce, advantage Me, game Me.
    let result = outcome(Self.format(), g(1, .me) + "MMMOOOM", last: "M")
    #expect(result == PointOutcome(winner: .me, level: .game, changeOfEnds: false))
  }

  @Test("US3 s1 a game won on the No-Ad deciding point is a game")  // ITF: NA-01
  func gameOnDecidingPoint() {
    let result = outcome(Self.format(.bestOfThree, .six, .noAd), g(1, .me) + "MMMOOO", last: "O")
    #expect(result == PointOutcome(winner: .opponent, level: .game, changeOfEnds: false))
  }

  @Test("US3 s2 a set won 6–4 is a set")  // ITF: ST-03, ST-07
  func setSixFour() {
    let result = outcome(Self.format(), g(5, .me) + g(4, .opponent) + "MMM", last: "M")
    #expect(result.level == .set)
    #expect(result.winner == .me)
  }

  @Test("US3 s2 a set won 7–6 in a tie-break is a set")  // ITF: ST-03, ST-07, TB-01
  func setInTieBreak() {
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let result = outcome(Self.format(), toSixAll + "OOOOOO", last: "O")
    #expect(result.level == .set)
    #expect(result.winner == .opponent)
  }

  @Test("US3 s3 the match won in a set is the match")  // ITF: MT-03
  func matchInSet() {
    let result = outcome(Self.format(.oneSet), g(5, .me) + "MMM", last: "M")
    #expect(result == PointOutcome(winner: .me, level: .match, changeOfEnds: false))
  }

  @Test("US3 s3 the match won 10–8 in a match tie-break is the match")  // ITF: MT-03
  func matchInMatchTieBreak() {
    let format = Self.format(matchTieBreak: true)
    let result = outcome(
      format, toMatchTieBreak + String(repeating: "MO", count: 8) + "O", last: "O")
    #expect(result.level == .match)
    #expect(result.winner == .opponent)
  }

  @Test("FR-011 positive control: a 6–5 game is a game, not a set")  // ITF: ST-03
  func sixFiveIsGame() {
    let result = outcome(Self.format(), g(5, .me) + g(5, .opponent) + "MMM", last: "M")
    #expect(result.level == .game)
  }

  // MARK: Change of ends (US3 s5)

  @Test("US3 s5 games 1 and 3 of a set call for a change of ends; game 2 doesn't")  // ITF: EN-01
  func oddGames() {
    #expect(
      outcome(Self.format(), "MMM", last: "M")
        == .init(winner: .me, level: .game, changeOfEnds: true))
    #expect(outcome(Self.format(), g(1, .me) + "MMM", last: "M").changeOfEnds == false)
    #expect(
      outcome(Self.format(), g(2, .me) + "OOO", last: "O")
        == .init(winner: .opponent, level: .game, changeOfEnds: true))
  }

  @Test("US3 s5 a set won 6–3 calls for a change of ends with the set")  // ITF: EN-02
  func setOddTotal() {
    let result = outcome(Self.format(), g(5, .me) + g(3, .opponent) + "MMM", last: "M")
    #expect(result == PointOutcome(winner: .me, level: .set, changeOfEnds: true))
  }

  @Test("US3 s5 a set won 6–4 has no change; game 1 of the next set has one")  // ITF: EN-02, EN-01
  func setEvenTotal() {
    let setup = g(5, .me) + g(4, .opponent) + "MMM"
    #expect(
      outcome(Self.format(), setup, last: "M")
        == .init(winner: .me, level: .set, changeOfEnds: false))
    #expect(
      outcome(Self.format(), setup + "M" + "OOO", last: "O")
        == .init(winner: .opponent, level: .game, changeOfEnds: true))
  }

  @Test("US3 s5 a set won 7–6 in a tie-break calls for a change of ends")  // ITF: EN-03
  func tieBreakSet() {
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let result = outcome(Self.format(), toSixAll + "MMMMMM", last: "M")
    #expect(result == PointOutcome(winner: .me, level: .set, changeOfEnds: true))
  }

  @Test("US3 s5 the set before a match tie-break: odd total changes ends, even doesn't")  // ITF: EN-04
  func setBeforeMatchTieBreak() {
    let format = Self.format(matchTieBreak: true)
    // Set 2 won 6–3 by Opponent (odd total).
    let odd = outcome(format, g(6, .me) + g(3, .me) + g(5, .opponent) + "OOO", last: "O")
    #expect(odd == PointOutcome(winner: .opponent, level: .set, changeOfEnds: true))
    // Set 2 won 6–4 by Opponent (even total).
    let even = outcome(format, g(6, .me) + g(4, .me) + g(5, .opponent) + "OOO", last: "O")
    #expect(even == PointOutcome(winner: .opponent, level: .set, changeOfEnds: false))
  }

  @Test("US3 s5 the 6th point of a set tie-break that doesn't end it changes ends")  // ITF: TB-05
  func sixthTieBreakPoint() {
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let result = outcome(Self.format(), toSixAll + "MMMOO", last: "O")
    #expect(result == PointOutcome(winner: .opponent, level: .point, changeOfEnds: true))
    // Positive control: the 5th point doesn't.
    #expect(outcome(Self.format(), toSixAll + "MMMO", last: "O").changeOfEnds == false)
  }

  @Test("US3 s5 the 6th point of a match tie-break that doesn't end it changes ends")  // ITF: TB-05
  func sixthMatchTieBreakPoint() {
    let format = Self.format(matchTieBreak: true)
    let result = outcome(format, toMatchTieBreak + "MMMOO", last: "O")
    #expect(result == PointOutcome(winner: .opponent, level: .point, changeOfEnds: true))
  }

  // MARK: Match point (US3 s6)

  @Test("US3 s6 a match won 6–3 on an odd game has no change of ends")  // ITF: EN-05, EN-01, EN-02
  func matchOnOddGame() {
    let result = outcome(Self.format(.oneSet), g(5, .me) + g(3, .opponent) + "MMM", last: "M")
    #expect(result == PointOutcome(winner: .me, level: .match, changeOfEnds: false))
  }

  @Test("US3 s6 a match tie-break won 10–8 on the 18th point has no change of ends")  // ITF: EN-05, TB-05
  func matchOnSixthMultiple() {
    let format = Self.format(matchTieBreak: true)
    let result = outcome(
      format, toMatchTieBreak + String(repeating: "MO", count: 8) + "M", last: "M")
    #expect(result == PointOutcome(winner: .me, level: .match, changeOfEnds: false))
  }
}
