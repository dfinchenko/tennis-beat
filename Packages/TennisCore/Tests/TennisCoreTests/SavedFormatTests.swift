import Foundation
import Testing

@testable import TennisCore

/// Saved format (FR-031, FR-032). See `specs/001-scoring-engine/contracts/saved-format.md`.
///
/// Fixtures under `Fixtures/saved-format/` are never edited after release: each released
/// `formatVersion` keeps its own file, and every later engine must restore it.
@Suite("SavedFormat")
struct SavedFormatTests {

  static func json(_ text: String) -> Data { Data(text.utf8) }

  static let validSetup =
    #"{"type":"setup","format":{"matchLength":"bestOfThree","setLength":6,"gameScoring":"advantage","matchTieBreak":false},"firstServer":"me"}"#

  @Test("US3 s8 save and restore gives the identical list, version and recorded times")
  func s8() throws {
    var m = try Match.make(.bestOfThree, setLength: .four, scoring: .noAd, matchTieBreak: true)
    let odd = [813_592_800.123_456_789, 0.1, -12.3e-7, 1e9 + 1.0 / 3.0]
    for (index, seconds) in odd.enumerated() {
      try m.recordPoint(
        wonBy: index.isMultiple(of: 2) ? .me : .opponent,
        at: Date(timeIntervalSinceReferenceDate: seconds))
    }
    let data = try MatchCodec.encode(m)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains(#""formatVersion":1"#))
    let restored = try MatchCodec.decode(data).get()
    #expect(restored == m)
    #expect(restored.state == m.state)
    for (a, b) in zip(restored.events, m.events) {
      if case .point(_, let ta) = a, case .point(_, let tb) = b {
        #expect(
          ta.timeIntervalSinceReferenceDate.bitPattern
            == tb.timeIntervalSinceReferenceDate.bitPattern
        )
      }
    }
  }

  @Test("US3 s13 the frozen v1 fixture restores to its recorded state")
  func s13() throws {
    let match = try MatchCodec.decode(Fixtures.data("v1", in: "saved-format")).get()
    let expected = try JSONDecoder().decode(
      StateSnapshot.self, from: Fixtures.data("v1.expected", in: "saved-format"))
    #expect(StateSnapshot(match, includeStats: expected.stats != nil) == expected)
    guard case .point(_, let first)? = match.events.dropFirst().first else {
      Issue.record("first event after setup is not a point")
      return
    }
    #expect(first == Date(timeIntervalSinceReferenceDate: 813_592_800.125))
  }

  @Test("US3 s14 a newer format version is rejected as unsupported without parsing the events")
  func s14() throws {
    let newer = Self.json(#"{"formatVersion":2,"events":[\#(Self.validSetup)]}"#)
    #expect(MatchCodec.decode(newer) == .failure(.unsupportedVersion(found: 2, supported: 1)))
    let newerGarbage = Self.json(#"{"formatVersion":2,"events":"not a list"}"#)
    #expect(
      MatchCodec.decode(newerGarbage) == .failure(.unsupportedVersion(found: 2, supported: 1)))
  }

  @Test("US3 s15 recorded times never affect state or stats, even out of order")
  func s15() throws {
    let winners = "MMOMOOMMMOMOOOMMMMOMOMOOOM"
    func list(times: [Double]) -> String {
      let points = zip(winners, times).map { winner, time in
        #"{"type":"point","winner":"\#(winner == "M" ? "me" : "opponent")","recordedAt":\#(time)}"#
      }
      return
        #"{"formatVersion":1,"events":[\#(Self.validSetup),\#(points.joined(separator: ","))]}"#
    }
    let ordered = (0..<winners.count).map { 1000.0 + Double($0) }
    var rng = SplitMix64(seed: SplitMix64.testSeed)
    let shuffled = ordered.shuffled(using: &rng).map { $0 * 3.7 - 99 }
    let a = try MatchCodec.decode(Self.json(list(times: ordered))).get()
    let b = try MatchCodec.decode(Self.json(list(times: shuffled))).get()
    #expect(a.state == b.state)
    #expect(a.stats == b.stats)
    #expect(a.events != b.events)
  }

  @Test("Codec malformed: unknown event type or missing format version")
  func malformed() throws {
    let unknownType = Self.json(
      #"{"formatVersion":1,"events":[\#(Self.validSetup),{"type":"lob","winner":"me"}]}"#)
    #expect(MatchCodec.decode(unknownType) == .failure(.malformed))
    let noVersion = Self.json(#"{"events":[\#(Self.validSetup)]}"#)
    #expect(MatchCodec.decode(noVersion) == .failure(.malformed))
    #expect(MatchCodec.decode(Self.json("not json")) == .failure(.malformed))
    // Positive control: the same list with a known type restores.
    let valid = Self.json(#"{"formatVersion":1,"events":[\#(Self.validSetup)]}"#)
    #expect(throws: Never.self) { try MatchCodec.decode(valid).get() }
  }
}
