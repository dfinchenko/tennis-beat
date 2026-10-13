import Foundation
import Testing

@testable import TennisCore

/// SC-004 (CI part). Runs in the debug configuration that CI's `swift test` uses (research R9).
@Suite("Performance")
struct PerformanceTests {

  /// Exactly 500 points of best of 3: 7–6 (7–5), 6–7 (5–7), 6–4. Every standard game has
  /// three deuces before it is won (14 points); each tie-break is 12 points: 34 × 14 + 2 × 12.
  static func fiveHundredPoints() throws -> Match {
    var m = try Match.make()
    func game(_ winner: Player) {
      let w = winner == .me ? "M" : "O"
      let l = winner == .me ? "O" : "M"
      m.play(w + w + w + l + l + l + String(repeating: w + l, count: 3) + w + w)
    }
    func games(_ order: String) {
      for c in order { game(c == "M" ? .me : .opponent) }
    }
    games("MOMOMOMOMOMO")
    m.play("MOMOMOMOMO MM")
    games("MOMOMOMOMOMO")
    m.play("MOMOMOMOMO OO")
    games("MOMOMOMOMM")
    return m
  }

  @Test("SC-004 a full recompute of a 500-point match takes under 10 ms (median of 10)")
  func sc004() throws {
    let built = try Self.fiveHundredPoints()
    #expect(built.pointCount == 500)
    #expect(built.state.status == .won(.me))
    #expect(built.state.completedSets.map(\.games) == [pair(7, 6), pair(6, 7), pair(6, 4)])
    let events = built.events
    let clock = ContinuousClock()

    var validated: [Duration] = []
    for _ in 0..<10 {
      validated.append(
        try clock.measure {
          let m = try Match(events: events)
          #expect(m.state.status == .won(.me))
          _ = m.stats
        })
    }
    var replayed: [Duration] = []
    for _ in 0..<10 {
      replayed.append(
        clock.measure {
          let r = Reducer.replay(
            setup: built.setup, effectiveFirstServer: built.effectiveFirstServer, events: events)
          #expect(r.status == .won(.me))
          _ = r.stats
        })
    }
    let medianValidated = validated.sorted()[5]
    let medianReplay = replayed.sorted()[5]
    print("SC-004 median: Match(events:) \(medianValidated), Reducer.replay \(medianReplay)")
    #expect(medianValidated < .milliseconds(10))
    #expect(medianReplay < .milliseconds(10))
  }
}
