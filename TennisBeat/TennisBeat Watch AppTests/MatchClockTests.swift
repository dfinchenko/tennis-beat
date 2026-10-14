import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// FR-022, data-model.md § MatchClock: start and stop (pause arrives in PR 3).
struct MatchClockTests {
  private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

  @Test("FR-022 elapsed grows with the clock and is never negative")
  func grows() {
    let clock = MatchClock(startedAt: start)
    #expect(clock.elapsed(at: start) == 0)
    #expect(clock.elapsed(at: start + 61) == 61)
    #expect(clock.elapsed(at: start - 5) == 0)
  }

  @Test("FR-022 elapsed stays fixed after stop")
  func fixedAfterStop() {
    var clock = MatchClock(startedAt: start)
    clock.stop(at: start + 90)
    #expect(clock.elapsed(at: start + 90) == 90)
    #expect(clock.elapsed(at: start + 4_000) == 90)
    #expect(clock.stoppedAt == start + 90)
  }

  @Test("FR-022 a second stop keeps the first")
  func stopOnce() {
    var clock = MatchClock(startedAt: start)
    clock.stop(at: start + 90)
    clock.stop(at: start + 200)
    #expect(clock.elapsed(at: start + 500) == 90)
  }

  @Test("FR-022 a 10-minute gap (the app in the background) counts in full")
  func backgroundGap() {
    let clock = MatchClock(startedAt: start)
    #expect(clock.elapsed(at: start + 30) == 30)
    #expect(clock.elapsed(at: start + 30 + 600) == 630)
  }
}
