import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// FR-022, data-model.md § MatchClock: start, stop, pause and resume.
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

  // MARK: Pause (User Story 4 s5, s6, s8)

  @Test("US4 s5 s6 pause freezes elapsed; resume continues from the same value")
  func pauseAndResume() {
    var clock = MatchClock(startedAt: start)
    clock.pause(at: start + 100)
    #expect(clock.isPaused)
    #expect(clock.elapsed(at: start + 100) == 100)
    #expect(clock.elapsed(at: start + 400) == 100)
    clock.resume(at: start + 400)
    #expect(!clock.isPaused)
    #expect(clock.elapsed(at: start + 400) == 100)
    #expect(clock.elapsed(at: start + 410) == 110)
  }

  @Test("US4 s8 every pause is excluded")
  func severalPauses() {
    var clock = MatchClock(startedAt: start)
    clock.pause(at: start + 60)
    clock.resume(at: start + 120)
    clock.pause(at: start + 180)
    clock.resume(at: start + 300)
    #expect(clock.elapsed(at: start + 360) == 360 - 60 - 120)
  }

  @Test("FR-022 a second pause or a resume while running changes nothing")
  func idempotent() {
    var clock = MatchClock(startedAt: start)
    clock.resume(at: start + 10)
    #expect(clock.elapsed(at: start + 20) == 20)
    clock.pause(at: start + 20)
    clock.pause(at: start + 50)
    clock.resume(at: start + 80)
    #expect(clock.elapsed(at: start + 80) == 20)
  }

  @Test("Edge: pause, then End — stop closes the pause and the duration excludes it")
  func stopWhilePaused() {
    var clock = MatchClock(startedAt: start)
    clock.pause(at: start + 100)
    clock.stop(at: start + 250)
    #expect(!clock.isPaused)
    #expect(clock.elapsed(at: start + 250) == 100)
    #expect(clock.elapsed(at: start + 9_000) == 100)
  }

  @Test("SC-004 a scripted 30-minute match with 4 pauses stays within 1 s of wall time minus pauses")
  func scriptedMatch() {
    var rng = SplitMix64(seed: SplitMix64.testSeed)
    var clock = MatchClock(startedAt: start)
    var now = start
    var paused: TimeInterval = 0
    var pausesLeft = 4
    var steps = 0
    while now.timeIntervalSince(start) < 30 * 60 {
      now += TimeInterval(Int.random(in: 5...40, using: &rng))
      steps += 1
      if pausesLeft > 0, steps.isMultiple(of: 9) {
        clock.pause(at: now)
        let length = TimeInterval(Int.random(in: 60...300, using: &rng))
        #expect(abs(clock.elapsed(at: now + length / 2) - (now.timeIntervalSince(start) - paused)) <= 1)
        now += length
        paused += length
        clock.resume(at: now)
        pausesLeft -= 1
      }
      let expected = now.timeIntervalSince(start) - paused
      #expect(abs(clock.elapsed(at: now) - expected) <= 1, "step \(steps)")
    }
    #expect(pausesLeft == 0)  // positive control: the script did pause 4 times
  }
}
