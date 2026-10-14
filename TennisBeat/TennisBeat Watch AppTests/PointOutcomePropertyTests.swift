import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// FR-010 property: over seeded random matches in every format, each added point gives
/// exactly one level, and that level agrees with the engine's own state changes.
@MainActor
struct PointOutcomePropertyTests {
  static let formats: [MatchFormat] = FormatChoice.allCombinations.compactMap(\.matchFormat)

  @Test("FR-010 property one level per point, agreeing with status, sets and games")
  func levelAgreesWithState() {
    var rng = SplitMix64(seed: SplitMix64.testSeed)
    var levelsSeen: Set<PointOutcome.Level> = []
    for index in 0..<500 {
      let format = Self.formats[index % Self.formats.count]
      var match = Match(setup: MatchSetup(format: format, firstServer: .me))
      var step = 0
      while match.state.status == .inProgress && step < 5_000 {
        let before = match.state
        let winner: Player = Bool.random(using: &rng) ? .me : .opponent
        do {
          try match.recordPoint(
            wonBy: winner, at: Date(timeIntervalSinceReferenceDate: Double(step)))
        } catch {
          Issue.record("seed \(SplitMix64.testSeed), match \(index): point rejected: \(error)")
          return
        }
        let after = match.state
        let outcome = PointOutcome.evaluate(before: before, after: after, winner: winner)
        levelsSeen.insert(outcome.level)

        let gamesBefore = before.games.me + before.games.opponent
        let gamesAfter = after.games.me + after.games.opponent
        let expected: PointOutcome.Level =
          if after.status != .inProgress {
            .match
          } else if after.completedSets.count > before.completedSets.count {
            .set
          } else if gamesAfter > gamesBefore { .game } else { .point }
        #expect(
          outcome.level == expected,
          "seed \(SplitMix64.testSeed), match \(index), point \(step)")
        #expect(outcome.winner == winner)
        // The flag follows the engine, except on the match-winning point.  ITF: EN-05
        #expect(outcome.changeOfEnds == (after.changeOfEnds && expected != .match))
        step += 1
      }
      #expect(match.state.status != .inProgress, "match \(index) did not finish")
    }
    // Positive control: the generator reached every level.
    #expect(levelsSeen == [.point, .game, .set, .match])
  }
}
