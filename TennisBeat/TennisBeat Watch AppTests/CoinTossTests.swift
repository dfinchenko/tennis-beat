import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// FR-003, User Story 1 s9.
@MainActor
struct CoinTossTests {
  @Test("US1 s9 the coin-toss result starts the match with that first server")  // ITF: SV-01
  func tossStartsMatch() throws {
    let suite = "CoinTossTests.\(UUID().uuidString)"
    let session = MatchSession(
      store: FormatStore(defaults: UserDefaults(suiteName: suite)!),
      haptics: RecordingHaptics(), announcer: RecordingAnnouncer(),
      workout: FakeWorkoutService.denied(),
      now: Date.init,
      coinToss: { .opponent })
    let result = session.tossCoin()
    #expect(result == .opponent)
    session.start(firstServer: result)
    let match = try #require(session.match)
    #expect(match.setup.firstServer == .opponent)
    #expect(match.state.server == .opponent)
  }

  @Test("FR-003 the coin toss picks each player with equal chance")  // ITF: SV-01
  func fairToss() {
    var generator = SplitMix64(seed: SplitMix64.testSeed)
    let tosses = 10_000
    var me = 0
    for _ in 0..<tosses where CoinToss.toss(using: &generator) == .me { me += 1 }
    let share = Double(me) / Double(tosses)
    #expect((0.48...0.52).contains(share), "share of Me: \(share)")
    // Positive control: both outcomes occur.
    #expect(me > 0 && me < tosses)
  }
}
