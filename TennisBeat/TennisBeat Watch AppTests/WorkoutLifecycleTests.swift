import Foundation
import HealthKit
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// The workout follows the match (spec 003 Story 2; data-model § WorkoutState; contract §4;
/// T024).
@MainActor
struct WorkoutLifecycleTests {
  @Test("US2 s1 with permission a tennis workout starts at the clock's start")
  func startsWithTheMatch() throws {
    let h = WorkoutHarness()
    #expect(h.fake.calls.isEmpty)  // positive control: nothing before the start
    h.start()
    let token = try #require(h.token)
    let startedAt = try #require(h.session.clock?.startedAt)
    #expect(h.fake.calls == [.start(at: startedAt, token: token)])
    #expect(h.session.workoutState == .running)
  }

  @Test("US2 s1 the workout also starts after the coin toss")
  func startsAfterCoinToss() {
    let h = WorkoutHarness()
    h.session.start(firstServer: h.session.tossCoin())
    #expect(h.kinds == [.start])
    #expect(h.session.workoutState == .running)
  }

  @Test("US2 s1, Q1 the workout is tennis with no location type, and New match has no new row")
  func configuration() {
    let configuration = HealthKitWorkoutService.configuration
    #expect(configuration.activityType == .tennis)
    #expect(configuration.locationType == .unknown)
    // The four 002 rows, and nothing for indoor or outdoor.
    #expect(Mirror(reflecting: FormatChoice()).children.count == 4)
  }

  @Test("US2 s3, FR-006 pause and resume follow the match")
  func pauseAndResume() {
    let h = WorkoutHarness()
    h.start()
    h.clock.advance(by: 30)
    h.session.pause()
    #expect(h.fake.calls.last == .pause(at: h.clock.current))
    #expect(h.session.workoutState == .paused)
    h.session.pause()  // already paused: no second call
    h.clock.advance(by: 60)
    h.session.resume()
    #expect(h.fake.calls.last == .resume(at: h.clock.current))
    #expect(h.session.workoutState == .running)
    h.session.resume()  // not paused: no call
    #expect(h.kinds == [.start, .pause, .resume])
  }

  @Test("US2 s3, FR-006 after a 30-minute match with three pauses the active time equals the clock")
  func activeTimeEqualsElapsed() throws {
    let h = WorkoutHarness()
    h.start()
    let points = MatchScript.games(4, for: .me)
    // 16 points over 30 minutes of play, with pauses of 2, 5 and 10 minutes.
    for (index, point) in points.enumerated() {
      h.clock.advance(by: 112.5)
      if [3, 7, 11].contains(index) {
        h.session.pause()
        h.clock.advance(by: [3: 120.0, 7: 300, 11: 600][index]!)
        h.session.resume()
      }
      h.tap(String(point))
    }
    let clock = try #require(h.session.clock)
    let stoppedAt = try #require(clock.stoppedAt)
    #expect(stoppedAt.timeIntervalSince(clock.startedAt) == 1800 + 1020)
    let active = Self.activeTime(h.fake.calls, end: stoppedAt)
    #expect(abs(active - clock.elapsed(at: stoppedAt)) <= 1)
    #expect(clock.excluded.count == 3)

    // Positive control: a session that skipped one resume() is caught.
    var skipped = h.fake.calls
    let firstResume = try #require(
      skipped.firstIndex { if case .resume = $0 { true } else { false } })
    skipped.remove(at: firstResume)
    #expect(abs(Self.activeTime(skipped, end: stoppedAt) - clock.elapsed(at: stoppedAt)) > 1)
  }

  @Test("US2 s4 the winning point pauses the workout and fixes the end date")
  func summaryOnWin() async throws {
    let h = WorkoutHarness()
    h.start()
    h.clock.advance(by: 600)
    h.win()
    #expect(h.session.route == .summary)
    let stoppedAt = try #require(h.session.clock?.stoppedAt)
    #expect(h.fake.calls.last == .pause(at: stoppedAt))
    #expect(h.session.workoutState == .summary(openedAt: stoppedAt))
    await h.sleeper.untilWaiting()
    #expect(h.sleeper.waiting == 1)
    #expect(h.sleeper.requested == [.seconds(600)])
  }

  @Test("US2 s4 a confirmed End with a point pauses the workout and fixes the end date")
  func summaryOnEarlyEnd() async throws {
    let h = WorkoutHarness()
    h.start()
    h.tap("M")
    h.clock.advance(by: 90)
    h.session.endEarly()
    #expect(h.session.route == .summary)
    #expect(h.fake.calls.last == .pause(at: h.clock.current))
    #expect(h.session.workoutState == .summary(openedAt: h.clock.current))
    await h.sleeper.untilWaiting()
    #expect(h.sleeper.waiting == 1)
  }

  @Test("US2 s4, #28 R6-6 End confirmed while paused: no second pause; Undo resumes, not paused")
  func endWhilePaused() async throws {
    let h = WorkoutHarness()
    h.start()
    h.tap("M")
    h.session.pause()
    h.clock.advance(by: 300)
    h.session.endEarly()
    #expect(h.kinds == [.start, .pause])
    #expect(h.session.workoutState == .summary(openedAt: h.clock.current))
    await h.sleeper.untilWaiting()
    #expect(h.sleeper.waiting == 1)
    h.clock.advance(by: 20)
    h.session.undo()
    #expect(h.fake.calls.last == .resume(at: h.clock.current))
    #expect(h.session.workoutState == .running)
    #expect(!h.session.isPaused)
  }

  @Test("US2 s5 Undo from the summary resumes the workout and cancels the 10-minute task")
  func undoFromSummary() async {
    let h = WorkoutHarness()
    h.start()
    h.win()
    await h.sleeper.untilWaiting()
    h.clock.advance(by: 45)
    h.session.undo()
    #expect(h.session.route == .playing)
    #expect(h.fake.calls.last == .resume(at: h.clock.current))
    #expect(h.session.workoutState == .running)
    await h.fireTimeout()  // the cancelled task wakes up and saves nothing
    #expect(h.saveCount == 0)
    #expect(h.session.workoutState == .running)
  }

  @Test("US2 s8, FR-008 End with 0 points discards the workout and never saves it")
  func zeroPointsDiscards() async {
    let h = WorkoutHarness()
    h.start()
    h.session.endEarly()
    #expect(h.session.route == .setup)
    #expect(h.kinds == [.start, .discard])
    #expect(h.session.workoutState == .discarded)
    await settle()
    #expect(h.sleeper.waiting == 0)

    // Every point undone, and End while paused.
    let undone = WorkoutHarness()
    undone.start()
    undone.tap("MO")
    undone.session.undo()
    undone.session.undo()
    undone.session.pause()
    undone.session.endEarly()
    #expect(undone.kinds == [.start, .pause, .discard])
    #expect(undone.session.workoutState == .discarded)
  }

  @Test("US2 s9 a workout that fails to start leaves the match running with no further call")
  func failingStart() async {
    let h = WorkoutHarness(.failing)
    h.start()
    await settle()
    #expect(h.session.workoutState == .failed)
    // #30 R1-1: the failed workout is ended, so its session can't stay active.
    #expect(h.kinds == [.start, .discard])
    h.tap("MMM")
    h.session.pause()
    h.session.resume()
    h.win()
    #expect(h.session.route == .summary)
    #expect(h.session.canUndo)  // R3-2: a failed workout keeps Undo
    h.session.done()
    await settle()
    #expect(h.kinds == [.start, .discard])
    #expect(h.sleeper.waiting == 0)
  }

  @Test("US2 s9 without permission no workout call is made at all")
  func deniedMakesNoCall() async {
    let h = WorkoutHarness(.denied)
    h.start()
    #expect(h.session.workoutState == .none)
    h.session.pause()
    h.session.resume()
    h.win()
    h.session.done()
    await settle()
    #expect(h.fake.calls.isEmpty)
    #expect(h.session.workoutState == .none)
  }

  @Test("US2 s10, #28 R6-4 a workout ended mid-match: saved best effort; the match goes on")
  func endedMidMatch() async throws {
    let h = WorkoutHarness()
    h.start()
    h.tap("MOM")
    h.clock.advance(by: 120)
    let before = h.snapshot
    h.fake.endUnexpectedly()
    await settle()
    #expect(h.session.workoutState == .failed)
    #expect(h.snapshot == before)  // FR-011
    #expect(h.fake.calls.last == .save(endingAt: h.clock.current))
    #expect(h.saveCount == 1)

    // The match continues as without a workout: no call, Undo kept, Done saves nothing.
    h.session.pause()
    h.session.resume()
    h.win()
    #expect(h.session.route == .summary)
    #expect(h.session.canUndo)
    await settle()
    #expect(h.sleeper.waiting == 0)
    h.session.done()
    await settle()
    #expect(h.kinds == [.start, .save])
    #expect(!h.session.pendingSaveFailureNotice)
  }

  @Test("US2 s10, #28 R6-4 a workout ended on the summary: saved at the opening; Undo kept")
  func endedOnSummary() async throws {
    let h = WorkoutHarness()
    h.start()
    h.win()
    let openedAt = try #require(h.session.clock?.stoppedAt)
    await h.sleeper.untilWaiting()
    h.clock.advance(by: 60)
    h.fake.endUnexpectedly()
    await settle()
    #expect(h.session.workoutState == .failed)
    #expect(h.fake.calls.last == .save(endingAt: openedAt))
    #expect(h.session.route == .summary)
    #expect(h.session.canUndo)
    await h.fireTimeout()  // the cancelled task saves nothing more
    h.session.done()
    await settle()
    #expect(h.saveCount == 1)
  }

  @Test("US2 s10, #28 R6-4 a failing best-effort save sets no notice")
  func endedSaveFailsSilently() async {
    let h = WorkoutHarness(saveFails: true)
    h.start()
    h.tap("M")
    h.fake.endUnexpectedly()
    await settle()
    #expect(h.saveCount == 1)
    #expect(h.session.workoutState == .failed)
    #expect(!h.session.pendingSaveFailureNotice)
    h.session.endEarly()
    h.session.done()
    await settle()
    #expect(!h.session.pendingSaveFailureNotice)
    #expect(h.saveCount == 1)
  }

  @Test(
    "FR-011 no workout event changes the match, the clock, the route or the pause",
    arguments: [
      WorkoutEvent.heartRate(HeartRateReading(bpm: 150, date: .distantPast)), .failed,
      .endedUnexpectedly,
    ])
  func eventsChangeNoMatchState(event: WorkoutEvent) async throws {
    for paused in [false, true] {
      let h = WorkoutHarness()
      h.start()
      h.tap("MMO")
      if paused { h.session.pause() }
      let before = h.snapshot
      let token = try #require(h.token)
      h.fake.emit(event, token: token)
      await settle()
      #expect(h.snapshot == before)
    }
  }

  @Test("R11 events of another workout are dropped")
  func otherTokenDropped() async {
    let h = WorkoutHarness()
    h.start()
    h.fake.emit(.endedUnexpectedly, token: WorkoutToken())
    h.fake.emit(.failed, token: WorkoutToken())
    await settle()
    #expect(h.session.workoutState == .running)
    #expect(h.kinds == [.start])
  }

  @Test("Edge: pause during a tie-break pauses and resumes the workout; the score is unchanged")  // ITF: TB-01
  func pauseInTieBreak() throws {
    let h = WorkoutHarness(format: PointOutcomeTests.format())
    h.start()
    h.tap(
      MatchScript.games(5, for: .me) + MatchScript.games(5, for: .opponent)
        + MatchScript.games(1, for: .me) + MatchScript.games(1, for: .opponent) + "MOM")
    let before = try #require(h.session.match?.state)
    #expect(before.isTieBreak)
    h.session.pause()
    #expect(h.session.workoutState == .paused)
    h.session.resume()
    #expect(h.session.workoutState == .running)
    #expect(h.kinds == [.start, .pause, .resume])
    let after = try #require(h.session.match?.state)
    #expect(after == before)
    #expect(after.server == before.server)
    #expect(after.courtSide == before.courtSide)
  }

  @Test("Edge: early end long after the last point ends the workout at the End, not the point")
  func earlyEndLongAfterLastPoint() {
    let h = WorkoutHarness()
    h.start()
    h.tap("M")
    let lastPoint = h.clock.current
    h.clock.advance(by: 1200)
    h.session.endEarly()
    #expect(lastPoint != h.clock.current)
    #expect(h.session.workoutState == .summary(openedAt: h.clock.current))
  }

  /// Active time from the fake's calls: from the start to `end`, minus the paused intervals.
  static func activeTime(_ calls: [FakeWorkoutService.Call], end: Date) -> TimeInterval {
    var start: Date?
    var pausedAt: Date?
    var paused: TimeInterval = 0
    for call in calls {
      switch call {
      case .start(let date, _): start = date
      case .pause(let date): if pausedAt == nil { pausedAt = date }
      case .resume(let date):
        if let from = pausedAt { paused += date.timeIntervalSince(from) }
        pausedAt = nil
      default: break
      }
    }
    guard let start else { return 0 }
    return (pausedAt ?? end).timeIntervalSince(start) - paused
  }
}
