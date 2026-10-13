import Foundation

@testable import TennisCore

/// Seeded random valid matches for the property tests (research R8).
///
/// Built in stages: points (US3), early ends (US7); first-server corrections (US8) are added
/// in their phase.
enum MatchGenerator {
  struct Generated {
    var index: Int
    var events: [MatchEvent]
  }

  static let formats: [MatchFormat] = {
    var formats: [MatchFormat] = []
    for setLength in [SetLength.four, .six, .eight] {
      for scoring in [GameScoring.advantage, .noAd] {
        for (length, matchTieBreak) in [
          (MatchLength.oneSet, false), (.bestOfThree, false), (.bestOfThree, true),
        ] {
          if let format = try? MatchFormat(
            length: length, setLength: setLength, gameScoring: scoring,
            matchTieBreak: matchTieBreak)
          {
            formats.append(format)
          }
        }
      }
    }
    return formats
  }()

  static func matches(count: Int = 1000, seed: UInt64 = SplitMix64.testSeed) -> [Generated] {
    var rng = SplitMix64(seed: seed)
    return (0..<count).map { index in
      Generated(index: index, events: match(using: &rng))
    }
  }

  static func match(using rng: inout SplitMix64) -> [MatchEvent] {
    let format = formats[Int.random(in: 0..<formats.count, using: &rng)]
    let first: Player = Bool.random(using: &rng) ? .me : .opponent
    var m = Match(setup: MatchSetup(format: format, firstServer: first))
    // A per-match bias makes long deuces, tie-breaks and match tie-breaks common.
    let bias = Double.random(in: 0.3...0.7, using: &rng)
    let stopAt: Int? = Bool.random(using: &rng) ? Int.random(in: 0...300, using: &rng) : nil
    var time = 813_592_800.0
    while m.state.status == .inProgress, m.pointCount < (stopAt ?? 2_000) {
      let winner: Player = Double.random(in: 0..<1, using: &rng) < bias ? .me : .opponent
      time += Double.random(in: 5...60, using: &rng)
      do {
        try m.recordPoint(wonBy: winner, at: Date(timeIntervalSinceReferenceDate: time))
      } catch {
        break
      }
    }
    var events = m.events
    // US7: one match in ten ends early at the point where it stopped.
    if m.state.status == .inProgress, Double.random(in: 0..<1, using: &rng) < 0.1 {
      events.append(.matchEndedEarly)
    }
    return events
  }
}
