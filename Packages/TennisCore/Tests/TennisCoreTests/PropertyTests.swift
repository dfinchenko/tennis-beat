import Foundation
import Testing

@testable import TennisCore

/// Plan-level properties over at least 1,000 seeded matches and all their prefixes.
/// Rerun a failure with `TENNISCORE_SEED=<seed>`.
@Suite("Properties")
struct PropertyTests {
  static let seed = SplitMix64.testSeed
  static let generated = MatchGenerator.matches(seed: seed)

  static func label(_ g: MatchGenerator.Generated) -> Comment {
    "seed \(seed), match \(g.index)"
  }

  @Test("P-1 the incrementally built match equals Reducer.replay for every prefix")
  func p1() throws {
    #expect(Self.generated.count >= 1000)
    for g in Self.generated {
      guard case .setup(let setup)? = g.events.first else { continue }
      var m = Match(setup: setup)
      for event in g.events.dropFirst() {
        try m.record(event)
        let replayed = Reducer.replay(
          setup: setup, effectiveFirstServer: m.effectiveFirstServer, events: m.events)
        guard m.reduction == replayed else {
          Issue.record("incremental != replay after \(m.events.count) events, \(Self.label(g))")
          break
        }
        #expect(m.state == replayed.state)
        #expect(m.stats == replayed.stats)
      }
    }
  }

  @Test("SC-002 undo then re-recording the same event returns the previous match")
  func sc002() throws {
    for g in Self.generated {
      var m = try Match(events: Array(g.events.prefix(1)))
      let start = m
      for event in g.events.dropFirst() {
        let before = m
        try m.record(event)
        let after = m
        guard m.undo() == event, m == before else {
          Issue.record(
            "undo did not restore the prefix of \(before.events.count) events, \(Self.label(g))")
          break
        }
        try m.record(event)
        guard m == after else {
          Issue.record("re-recording differs after \(after.events.count) events, \(Self.label(g))")
          break
        }
      }
      while m.undo() != nil {}
      #expect(m == start, Self.label(g))
    }
  }

  @Test("SC-003 save and restore reproduces the identical match, including stats")
  func sc003() throws {
    for g in Self.generated {
      let m = try Match(events: g.events)
      let restored = try MatchCodec.decode(MatchCodec.encode(m)).get()
      guard restored == m, restored.stats == m.stats else {
        Issue.record("round trip differs, \(Self.label(g))")
        continue
      }
    }
  }
}
