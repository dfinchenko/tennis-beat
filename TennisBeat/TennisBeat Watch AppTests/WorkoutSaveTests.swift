import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// Saving the workout: once per match with points, at the last summary opening, on Done or
/// after 10 minutes (spec 003 Story 2 s6, s7, Story 4 s4–s7; FR-007, FR-009, FR-015; T025).
@MainActor
struct WorkoutSaveTests {
  nonisolated enum Step: CustomStringConvertible, Sendable {
    case point(String)
    case pause, resume, undo, endEarly, done, timeout, win

    var description: String {
      switch self {
      case .point(let points): "point \(points)"
      case .pause: "pause"
      case .resume: "resume"
      case .undo: "undo"
      case .endEarly: "endEarly"
      case .done: "done"
      case .timeout: "timeout"
      case .win: "win"
      }
    }
  }

  /// A scripted match: each step with the calls the fake has after it.
  nonisolated struct Script: CustomTestStringConvertible, Sendable {
    let name: String
    let steps: [(Step, [CallKind])]
    let saves: Int

    var testDescription: String { name }
  }

  nonisolated static let scripts: [Script] = [
    Script(
      name: "won", steps: [(.win, [.start, .pause]), (.done, [.start, .pause, .save])], saves: 1),
    Script(
      name: "paused, resumed, won",
      steps: [
        (.pause, [.start, .pause]), (.resume, [.start, .pause, .resume]),
        (.win, [.start, .pause, .resume, .pause]),
        (.done, [.start, .pause, .resume, .pause, .save]),
      ], saves: 1),
    Script(
      name: "summary Undo, won again",
      steps: [
        (.win, [.start, .pause]), (.undo, [.start, .pause, .resume]),
        (.point("M"), [.start, .pause, .resume, .pause]),
        (.done, [.start, .pause, .resume, .pause, .save]),
      ], saves: 1),
    Script(
      name: "timeout on the summary, then Done",
      steps: [
        (.win, [.start, .pause]), (.timeout, [.start, .pause, .save]),
        (.undo, [.start, .pause, .save]), (.done, [.start, .pause, .save]),
      ], saves: 1),
    Script(
      name: "early end with a point",
      steps: [
        (.point("M"), [.start]), (.endEarly, [.start, .pause]),
        (.done, [.start, .pause, .save]),
      ], saves: 1),
    Script(
      name: "early end while paused",
      steps: [
        (.point("MO"), [.start]), (.pause, [.start, .pause]), (.endEarly, [.start, .pause]),
        (.done, [.start, .pause, .save]),
      ], saves: 1),
    Script(name: "early end without points", steps: [(.endEarly, [.start, .discard])], saves: 0),
    Script(
      name: "early end after undoing every point",
      steps: [
        (.point("M"), [.start]), (.undo, [.start]), (.endEarly, [.start, .discard]),
      ], saves: 0),
  ]

  @Test(
    "SC-002 scripted matrix: the calls after every step; one save per match with points",
    arguments: scripts)
  func scriptedMatrix(script: Script) async {
    let h = WorkoutHarness()
    h.start()
    #expect(h.kinds == [.start])
    for (step, expected) in script.steps {
      switch step {
      case .point(let points): h.tap(points)
      case .pause: h.session.pause()
      case .resume: h.session.resume()
      case .undo: h.session.undo()
      case .endEarly: h.session.endEarly()
      case .done: h.session.done()
      case .timeout: await h.fireTimeout()
      case .win: h.win()
      }
      await settle()
      #expect(h.kinds == expected, "after \(step)")
    }
    #expect(h.saveCount == script.saves)
  }

  @Test("US4 s6, SC-003 the saved span equals the summary's Duration", arguments: [false, true])
  func savedSpanEqualsDuration(earlyEnd: Bool) async throws {
    let h = WorkoutHarness()
    h.start()
    h.clock.advance(by: 300)
    h.tap("MMO")
    h.session.pause()
    h.clock.advance(by: 240)
    h.session.resume()
    h.clock.advance(by: 400)
    if earlyEnd { h.session.endEarly() } else { h.win() }
    let clock = try #require(h.session.clock)
    let stoppedAt = try #require(clock.stoppedAt)
    h.clock.advance(by: 30)  // time on the summary
    h.session.done()
    await settle()
    #expect(h.fake.calls.last == .save(endingAt: stoppedAt))
    let saved = WorkoutLifecycleTests.activeTime(h.fake.calls, end: stoppedAt)
    #expect(abs(saved - clock.elapsed(at: stoppedAt)) <= 1)
  }

  @Test("US2 s6, US4 s4 Done saves once at the summary opening; New match opens at once")
  func doneSaves() async throws {
    let h = WorkoutHarness()
    let gate = SaveGate()
    h.fake.beforeSaveReturns = { await gate.wait() }
    h.start()
    h.win()
    let openedAt = try #require(h.session.clock?.stoppedAt)
    h.clock.advance(by: 20)
    h.session.done()
    #expect(h.session.route == .setup)  // before the save returns (FR-010)
    #expect(h.fake.calls.last == .save(endingAt: openedAt))
    #expect(h.session.workoutState == .saving)
    await settle()
    #expect(gate.waiting == 1)
    gate.open()
    await settle()
    #expect(h.session.workoutState == .saved)
    #expect(h.saveCount == 1)
    #expect(!h.session.pendingSaveFailureNotice)
  }

  @Test("US2 s7 after 10 minutes the workout is saved and Undo is gone; Done saves nothing more")
  func timeoutSaves() async throws {
    let h = WorkoutHarness()
    h.start()
    h.win()
    let openedAt = try #require(h.session.clock?.stoppedAt)
    #expect(h.session.canUndo)
    await h.fireTimeout()
    #expect(h.sleeper.requested == [.seconds(600)])
    #expect(h.fake.calls.last == .save(endingAt: openedAt))
    #expect(h.session.workoutState == .saved)
    #expect(h.session.route == .summary)
    #expect(!h.session.canUndo)
    h.session.done()
    await settle()
    #expect(h.session.route == .setup)
    #expect(h.saveCount == 1)
  }

  @Test("US2 s7, research R4 the scene-phase safety net saves at 10 minutes, not at 9:59")
  func safetyNet() async throws {
    let h = WorkoutHarness()
    h.start()
    h.win()
    let openedAt = try #require(h.session.clock?.stoppedAt)
    h.clock.advance(by: 599)
    h.session.checkSummaryTimeout()
    await settle()
    #expect(h.saveCount == 0)  // positive control: at 9:59 nothing is saved
    #expect(h.session.canUndo)
    h.clock.advance(by: 1)
    h.session.checkSummaryTimeout()
    await settle()
    #expect(h.fake.calls.last == .save(endingAt: openedAt))
    #expect(h.session.workoutState == .saved)
    await h.fireTimeout()  // the timer firing late saves nothing more
    #expect(h.saveCount == 1)
  }

  @Test("US2 s7, R3-2 a failed timeout save brings Undo back; the match goes on with no workout")
  func timeoutSaveFails() async {
    let h = WorkoutHarness(saveFails: true)
    h.start()
    h.win()
    await h.fireTimeout()
    #expect(h.saveCount == 1)
    #expect(h.session.workoutState == .failed)
    #expect(h.session.canUndo)
    #expect(h.session.pendingSaveFailureNotice)  // shown on New match after Done (R1-6)
    h.session.undo()
    #expect(h.session.route == .playing)
    #expect(h.kinds == [.start, .pause, .save])  // no resume: there is no workout now
    h.tap("M")
    #expect(h.session.route == .summary)
    h.session.done()
    await settle()
    #expect(h.kinds == [.start, .pause, .save])
    #expect(h.session.pendingSaveFailureNotice)
  }

  @Test("US2 s7, R1-2 without a workout the summary keeps Undo however long it is open")
  func deniedKeepsUndo() async {
    let h = WorkoutHarness(.denied)
    h.start()
    h.win()
    await settle()
    #expect(h.sleeper.waiting == 0)  // no task started
    h.clock.advance(by: 3600)
    h.session.checkSummaryTimeout()
    await settle()
    #expect(h.session.canUndo)
    #expect(h.fake.calls.isEmpty)
  }

  @Test("US4 s5, FR-009 win, Undo, win again, Done: one save, ending at the second opening")
  func undoThenWinAgain() async throws {
    let h = WorkoutHarness()
    h.start()
    let startedAt = try #require(h.session.clock?.startedAt)
    let token = try #require(h.token)
    h.win()
    let first = try #require(h.session.clock?.stoppedAt)
    h.clock.advance(by: 120)
    h.session.undo()
    let undoneAt = h.clock.current
    h.clock.advance(by: 60)
    h.tap("M")
    let second = try #require(h.session.clock?.stoppedAt)
    #expect(second != first)
    h.session.done()
    await settle()
    // The first summary's time is a paused interval: pause at the first opening, resume at Undo.
    #expect(
      h.fake.calls == [
        .start(at: startedAt, token: token), .pause(at: first), .resume(at: undoneAt),
        .pause(at: second), .save(endingAt: second),
      ])
  }

  @Test("FR-009 a double Done, and Done after the timeout save, never save twice")
  func noSecondSave() async {
    let h = WorkoutHarness()
    h.start()
    h.win()
    h.session.done()
    h.session.done()
    await settle()
    #expect(h.saveCount == 1)

    let timed = WorkoutHarness()
    timed.start()
    timed.win()
    await timed.fireTimeout()
    timed.session.done()
    timed.session.done()
    await settle()
    #expect(timed.saveCount == 1)
  }

  @Test("R5-2 end date: the saved workout ends no earlier than its last pause event")
  func endDateAfterLastEvent() async throws {
    let h = WorkoutHarness()
    h.fake.eventDelay = 0.005
    h.start()
    h.win()
    let stoppedAt = try #require(h.session.clock?.stoppedAt)
    h.session.done()
    await settle()
    let lastPause = try #require(
      h.fake.eventDates.last, "the fake records the dates HealthKit would stamp")
    let end = try #require(h.fake.savedEndDates.last)
    #expect(lastPause > stoppedAt)  // positive control: the event is after the clock's stop
    #expect(end >= lastPause)
    #expect(abs(end.timeIntervalSince(stoppedAt)) < 1)
  }

  @Test("R5-2 the effective end is the later of the summary opening and the last event")
  func effectiveEnd() {
    let opened = Date(timeIntervalSinceReferenceDate: 1000)
    #expect(WorkoutEndDate.effective(requested: opened, eventDates: []) == opened)
    #expect(
      WorkoutEndDate.effective(requested: opened, eventDates: [opened - 5, opened + 0.004])
        == opened + 0.004)
    #expect(WorkoutEndDate.effective(requested: opened, eventDates: [opened - 5]) == opened)
  }

  @Test("R5-3 Done, then a new match at once: the old workout's events change nothing")
  func doneThenStartAtOnce() async throws {
    let h = WorkoutHarness()
    let gate = SaveGate()
    h.fake.beforeSaveReturns = { await gate.wait() }
    h.start()
    h.win()
    let old = try #require(h.token)
    h.session.done()
    h.start()
    let new = try #require(h.token)
    #expect(new != old)
    let calls = h.fake.calls
    #expect(h.session.workoutState == .running)
    h.fake.emit(.endedUnexpectedly, token: old)
    h.fake.emit(.heartRate(HeartRateReading(bpm: 120, date: h.clock.current)), token: old)
    await settle()
    h.fake.saveFails = true  // the old save fails after the new match started
    gate.open()
    await settle()
    #expect(h.session.workoutState == .running)
    #expect(h.session.latestHeartRate == nil)
    #expect(h.fake.calls == calls)
    #expect(h.session.pendingSaveFailureNotice)
  }

  @Test("US4 s7, FR-015 Done with a failing save sets the notice once the save returns")
  func doneSaveFails() async {
    let h = WorkoutHarness(saveFails: true)
    let gate = SaveGate()
    h.fake.beforeSaveReturns = { await gate.wait() }
    h.start()
    h.win()
    h.session.done()
    #expect(h.session.route == .setup)
    await settle()
    #expect(!h.session.pendingSaveFailureNotice)
    gate.open()
    await settle()
    #expect(h.session.pendingSaveFailureNotice)
    h.session.dismissSaveFailureNotice()
    #expect(!h.session.pendingSaveFailureNotice)
  }

  @Test(
    "US4 s7, #28 R6-3 a timeout save still running at Done: Undo hidden; its failure sets the notice"
  )
  func timeoutSaveRunningAtDone() async {
    let h = WorkoutHarness(saveFails: true)
    let gate = SaveGate()
    h.fake.beforeSaveReturns = { await gate.wait() }
    h.start()
    h.win()
    await h.fireTimeout()
    #expect(h.session.workoutState == .saving)
    #expect(!h.session.canUndo)  // R6-3: hidden from the start of the save
    h.session.undo()
    #expect(h.session.route == .summary)
    h.session.done()
    #expect(h.session.route == .setup)
    gate.open()
    await settle()
    #expect(h.saveCount == 1)
    #expect(h.session.pendingSaveFailureNotice)
  }

  @Test("Edge: summary left open, then Undo after the 10-minute save does nothing")
  func undoAfterSaved() async {
    let h = WorkoutHarness()
    h.start()
    h.win()
    await h.fireTimeout()
    #expect(h.session.workoutState == .saved)
    let calls = h.fake.calls
    let match = h.session.match
    h.session.undo()
    #expect(h.session.route == .summary)
    #expect(h.session.match == match)
    #expect(h.fake.calls == calls)
  }

  // MARK: The summary snapshot (FR-013, research R7; T048)

  static let atOpening = WorkoutStatistics(
    averageHeartRate: 138, maximumHeartRate: 171, activeEnergy: 612)
  static let later = WorkoutStatistics(
    averageHeartRate: 140, maximumHeartRate: 180, activeEnergy: 650)
  static let saved = WorkoutStatistics(
    averageHeartRate: 139, maximumHeartRate: 171, activeEnergy: 615)

  @Test("FR-013 the summary snapshot is statistics() at the summary opening")
  func snapshotAtOpening() async {
    let h = WorkoutHarness()
    h.fake.stats = Self.atOpening
    h.start()
    h.tap("M")
    #expect(h.session.summaryStatistics == nil)  // none during the match
    h.win()
    h.fake.stats = Self.later  // a later sample doesn't change the summary
    await settle()
    #expect(h.session.summaryStatistics == Self.atOpening)
  }

  @Test("FR-013 an early end with a point takes the snapshot too, also while paused")
  func snapshotAtEarlyEnd() {
    for paused in [false, true] {
      let h = WorkoutHarness()
      h.fake.stats = Self.atOpening
      h.start()
      h.tap("M")
      if paused { h.session.pause() }
      h.session.endEarly()
      #expect(h.session.summaryStatistics == Self.atOpening, "paused: \(paused)")
    }
  }

  @Test("FR-013, R7 after the timeout save the summary shows the saved workout's statistics")
  func snapshotAfterTimeoutSave() async {
    let h = WorkoutHarness()
    h.fake.stats = Self.atOpening
    h.fake.savedStats = Self.saved
    h.start()
    h.win()
    #expect(h.session.summaryStatistics == Self.atOpening)
    await h.fireTimeout()
    #expect(h.session.workoutState == .saved)
    #expect(h.session.summaryStatistics == Self.saved)
  }

  @Test("FR-013 Undo from the summary drops the snapshot; the next opening takes a new one")
  func undoDropsSnapshot() async {
    let h = WorkoutHarness()
    h.fake.stats = Self.atOpening
    h.start()
    h.win()
    #expect(h.session.summaryStatistics == Self.atOpening)
    h.session.undo()
    #expect(h.session.summaryStatistics == nil)
    h.fake.stats = Self.later
    h.tap("M")
    #expect(h.session.route == .summary)
    #expect(h.session.summaryStatistics == Self.later)
  }

  @Test("US4 s3, R3-2 a failed timeout save drops the snapshot: Duration only")
  func failedTimeoutSaveDropsSnapshot() async {
    let h = WorkoutHarness(saveFails: true)
    h.fake.stats = Self.atOpening
    h.start()
    h.win()
    #expect(h.session.summaryStatistics == Self.atOpening)  // positive control
    await h.fireTimeout()
    #expect(h.session.workoutState == .failed)
    #expect(h.session.summaryStatistics == nil)
  }

  @Test("US4 s3 the workout failing or ending unexpectedly on the summary drops the snapshot")
  func failureOnSummaryDropsSnapshot() async throws {
    for event in [WorkoutEvent.failed, .endedUnexpectedly] {
      let h = WorkoutHarness()
      h.fake.stats = Self.atOpening
      h.start()
      h.win()
      #expect(h.session.summaryStatistics == Self.atOpening)
      h.fake.emit(event, token: try #require(h.token))
      await settle()
      #expect(h.session.workoutState == .failed, "\(event)")
      #expect(h.session.summaryStatistics == nil, "\(event)")
    }
  }

  @Test("US4 s3 without a workout, or after it failed to start, there is no snapshot")
  func noWorkoutNoSnapshot() async {
    for mode in [FakeHealthMode.denied, .failing] {
      let h = WorkoutHarness(mode)
      h.fake.stats = Self.atOpening
      h.start()
      await settle()  // `failing` reports the failure after start
      h.win()
      #expect(h.session.summaryStatistics == nil, "\(mode)")
    }
  }

  @Test("FR-013, FR-014 Done clears the snapshot; the next match starts without one")
  func doneClearsSnapshot() async {
    let h = WorkoutHarness()
    h.fake.stats = Self.atOpening
    h.start()
    h.win()
    #expect(h.session.summaryStatistics == Self.atOpening)
    h.session.done()
    #expect(h.session.summaryStatistics == nil)
    await settle()
    #expect(h.session.summaryStatistics == nil)  // the save's result doesn't bring it back
  }
}
