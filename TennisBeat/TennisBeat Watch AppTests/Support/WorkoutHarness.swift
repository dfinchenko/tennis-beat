import Foundation
import TennisCore

@testable import TennisBeat_Watch_App

/// A session with the fake workout service, a hand-moved clock and a hand-ended sleep, for
/// the spec 003 lifecycle tests (SC-002). The format is one set of 4 games, so 16 straight
/// points win the match.
@MainActor
final class WorkoutHarness {
  let clock = FakeClock()
  let sleeper = ManualSleep()
  let fake: FakeWorkoutService
  let session: MatchSession

  init(
    _ mode: FakeHealthMode = .granted, saveFails: Bool = false,
    format: MatchFormat = PointOutcomeTests.format(.oneSet, .four)
  ) {
    fake = FakeWorkoutService(mode: mode, now: clock.now, saveFails: saveFails)
    session = MatchSession(
      store: FormatStore(defaults: UserDefaults(suiteName: "WorkoutHarness.\(UUID().uuidString)")!),
      haptics: RecordingHaptics(), announcer: RecordingAnnouncer(), workout: fake,
      now: clock.now, makeFormat: { _ in format }, sleep: sleeper.sleep)
  }

  /// Starts the match with Me serving.
  func start() { session.start(firstServer: .me) }

  /// `M` = a point for Me, `O` = for the Opponent; spaces are ignored.
  func tap(_ points: String) {
    for character in points where character != " " {
      session.addPoint(for: character == "M" ? .me : .opponent)
    }
  }

  /// Wins the match from 0–0 in the first game (one set of 4 games).
  func win() { tap(MatchScript.games(4, for: .me)) }

  /// The token of the workout the fake started last.
  var token: WorkoutToken? { fake.currentToken }

  /// The calls as kinds, for the scripted matrix.
  var kinds: [CallKind] { fake.calls.compactMap(CallKind.init) }

  var saveCount: Int { kinds.filter { $0 == .save }.count }

  /// Lets the 10-minute task reach its sleep, ends it, and lets the save run.
  func fireTimeout() async {
    await sleeper.untilWaiting()
    sleeper.release()
    await settle()
  }

  /// What a workout event must not change (FR-011).
  struct Snapshot: Equatable {
    let match: Match?
    let clock: MatchClock?
    let route: MatchSession.Route
    let isPaused: Bool
  }

  var snapshot: Snapshot {
    Snapshot(
      match: session.match, clock: session.clock, route: session.route,
      isPaused: session.isPaused)
  }
}

nonisolated enum CallKind: Hashable, Sendable {
  case start, pause, resume, save, discard

  init?(_ call: FakeWorkoutService.Call) {
    switch call {
    case .start: self = .start
    case .pause: self = .pause
    case .resume: self = .resume
    case .save: self = .save
    case .discard: self = .discard
    case .requestAuthorization, .recoverAndSave: return nil
    }
  }
}

/// A gate a fake save waits on, so a test can hold the save back (`fake.beforeSaveReturns`).
@MainActor
final class SaveGate {
  private var waiters: [CheckedContinuation<Void, Never>] = []

  var waiting: Int { waiters.count }

  func wait() async { await withCheckedContinuation { waiters.append($0) } }

  func open() {
    let current = waiters
    waiters = []
    current.forEach { $0.resume() }
  }
}
