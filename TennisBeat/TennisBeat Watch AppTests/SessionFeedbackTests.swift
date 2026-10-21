import Foundation
import TennisCore
import Testing
import WatchKit

@testable import TennisBeat_Watch_App

/// SC-003, FR-011, FR-012, FR-013, FR-024: haptics and announcements per command
/// (contract §4).
@MainActor
struct SessionFeedbackTests {
  private let clock = FakeClock()
  private let haptics = RecordingHaptics()
  private let announcer = RecordingAnnouncer()
  private let g = MatchScript.games

  private func makeSession(
    _ format: MatchFormat = PointOutcomeTests.format(), firstServer: Player = .me
  ) -> MatchSession {
    let suite = "SessionFeedbackTests.\(UUID().uuidString)"
    let session = MatchSession(
      store: FormatStore(defaults: UserDefaults(suiteName: suite)!), haptics: haptics,
      announcer: announcer, workout: FakeWorkoutService.denied(), now: clock.now,
      makeFormat: { _ in format },
      locale: { Locale(identifier: "en") })
    session.start(firstServer: firstServer)
    return session
  }

  /// Taps `points` (`M` / `O`) through the session.
  private func tap(_ points: String, on session: MatchSession) {
    for character in points where character != " " {
      session.addPoint(for: character == "M" ? .me : .opponent)
    }
  }

  /// Taps `setup`, clears the fakes, then taps `last`.
  private func feedback(
    _ session: MatchSession, _ setup: String, last: String
  ) -> (haptics: [Haptic], announcements: [String]) {
    tap(setup, on: session)
    haptics.reset()
    announcer.reset()
    tap(last, on: session)
    return (haptics.haptics, announcer.announcements)
  }

  // MARK: Haptics per added point (US3 s1–s5)

  @Test("US3 s4 a point that wins no game plays the point haptic only")
  func pointHaptic() {
    #expect(feedback(makeSession(), "", last: "M").haptics == [.point])
  }

  @Test("US3 s1 a game plays the game haptic")  // ITF: GM-02
  func gameHaptic() {
    #expect(feedback(makeSession(), g(1, .me) + "MMM", last: "M").haptics == [.game])
  }

  @Test("US3 s2 a set plays the set haptic, not the game haptic")  // ITF: ST-03
  func setHaptic() {
    let result = feedback(makeSession(), g(4, .me) + g(5, .opponent) + "OOO", last: "O")
    #expect(result.haptics == [.set])
  }

  @Test("US3 s3 the match plays the match haptic only")  // ITF: MT-03
  func matchHaptic() {
    let session = makeSession(PointOutcomeTests.format(.oneSet))
    #expect(feedback(session, g(5, .me) + "MMM", last: "M").haptics == [.match])
  }

  @Test("US3 s5 change of ends follows the point's haptic: game, set and tie-break point")  // ITF: EN-01, EN-02, TB-05
  func changeOfEndsAfterPointHaptic() {
    #expect(feedback(makeSession(), "MMM", last: "M").haptics == [.game, .changeOfEnds])
    // A 6–3 set: set haptic, then change of ends.  ITF: EN-02
    let set = feedback(makeSession(), g(5, .me) + g(3, .opponent) + "MMM", last: "M")
    #expect(set.haptics == [.set, .changeOfEnds])
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let tieBreak = feedback(makeSession(), toSixAll + "MMMOO", last: "O")
    #expect(tieBreak.haptics == [.point, .changeOfEnds])
  }

  @Test("US3 s6 the match-winning point plays no change-of-ends haptic")  // ITF: EN-05
  func noChangeOnMatchPoint() {
    let session = makeSession(PointOutcomeTests.format(.oneSet))
    #expect(feedback(session, g(5, .me) + g(3, .opponent) + "MMM", last: "M").haptics == [.match])
  }

  // MARK: Undo (US3 s7)

  @Test("US3 s7 undo of a game-winning point plays no haptic")
  func undoGamePlaysNothing() {
    let session = makeSession()
    tap(g(1, .me) + "MMMM", on: session)
    haptics.reset()
    session.undo()
    #expect(haptics.haptics.isEmpty)
    #expect(haptics.calls == [.cancelPending])
    // Positive control: the undo did happen.
    #expect(session.match?.state.games == PlayerPair(me: 1, opponent: 0))
  }

  @Test("US3 s7 undo that brings back a change-of-ends state plays no haptic")  // ITF: EN-01
  func undoToChangeOfEndsState() {
    let session = makeSession()
    tap("MMMM" + "M", on: session)
    haptics.reset()
    session.undo()
    #expect(session.match?.state.changeOfEnds == true)  // the state reads "change"
    #expect(haptics.haptics.isEmpty)
  }

  @Test("Edge: a change-of-ends point undone and played again plays the haptic again")  // ITF: EN-01
  func replayedChangeOfEnds() {
    let session = makeSession()
    tap("MMM", on: session)
    haptics.reset()
    tap("M", on: session)
    session.undo()
    tap("M", on: session)
    #expect(haptics.haptics == [.game, .changeOfEnds, .game, .changeOfEnds])
  }

  @Test("FR-012 undo cancels the pending haptic first; an added point flushes it, never cancels")
  func pendingCalls() {
    let session = makeSession()
    tap("M", on: session)
    #expect(haptics.calls.first == .flushPending)
    #expect(!haptics.calls.contains(.cancelPending))
    haptics.reset()
    session.undo()
    #expect(haptics.calls == [.cancelPending])
  }

  @Test("US2 s3 after the match is won a tap adds nothing and requests no haptic")  // ITF: MT-08
  func noHapticAfterWin() {
    let session = makeSession(PointOutcomeTests.format(.oneSet))
    tap(g(6, .me), on: session)
    haptics.reset()
    announcer.reset()
    session.addPoint(for: .opponent)
    #expect(haptics.calls.isEmpty)
    #expect(announcer.announcements.isEmpty)
  }

  // MARK: WatchHaptics timing (FR-012, research R3)

  private func changeOfEndsGame() -> PointOutcome {
    PointOutcome(winner: .me, level: .game, changeOfEnds: true)
  }

  @Test("FR-012 undo before the delay ends: only the point's haptic plays")
  func undoCancelsDelayedHaptic() async {
    var played: [WKHapticType] = []
    let sleep = ManualSleep()
    let watch = WatchHaptics(sink: { played.append($0) }, sleep: sleep.sleep)
    watch.play(changeOfEndsGame())
    await sleep.untilWaiting()
    watch.cancelPending()
    sleep.release()
    await settle()
    #expect(played == [.directionUp])
  }

  @Test("FR-012 another point before the delay ends: point 1, change of ends, point 2")
  func pointFlushesDelayedHaptic() async {
    var played: [WKHapticType] = []
    let sleep = ManualSleep()
    let watch = WatchHaptics(sink: { played.append($0) }, sleep: sleep.sleep)
    watch.play(changeOfEndsGame())
    await sleep.untilWaiting()
    watch.flushPending()
    watch.play(PointOutcome(winner: .opponent, level: .point, changeOfEnds: false))
    sleep.release()
    await settle()
    #expect(played == [.directionUp, .retry, .click])
  }

  @Test("FR-012 positive control: without a later command the change of ends plays after the delay")
  func delayedHapticPlays() async {
    var played: [WKHapticType] = []
    let sleep = ManualSleep()
    let watch = WatchHaptics(sink: { played.append($0) }, sleep: sleep.sleep)
    watch.play(changeOfEndsGame())
    await sleep.untilWaiting()
    #expect(sleep.waiting == 1)
    #expect(played == [.directionUp])
    sleep.release()
    await settle()
    #expect(played == [.directionUp, .retry])
  }

  @Test("-uiTestHoldChangeOfEnds: the change of ends stays pending until the next command")
  func launchedHoldsTheChangeOfEnds() async {
    var played: [WKHapticType] = []
    let options = LaunchOptions(arguments: ["-uiTestHoldChangeOfEnds"])
    #expect(options.holdChangeOfEnds)
    let watch = WatchHaptics.launched(options, sink: { played.append($0) })
    watch.play(changeOfEndsGame())
    await settle(200)
    #expect(played == [.directionUp])  // still pending
    watch.flushPending()
    #expect(played == [.directionUp, .retry])

    watch.play(changeOfEndsGame())
    watch.cancelPending()
    await settle()
    #expect(played == [.directionUp, .retry, .directionUp])
  }

  @Test("-uiTestHoldChangeOfEnds is off by default: the launched haptics wait the usual delay")
  func launchedWithoutHold() async {
    var played: [WKHapticType] = []
    let options = LaunchOptions(arguments: [])
    #expect(options.holdChangeOfEnds == false)
    let watch = WatchHaptics.launched(options, sink: { played.append($0) })
    watch.play(changeOfEndsGame())
    #expect(played == [.directionUp])
    // The real 0.8 s sleep: the change of ends plays on its own (#36 R1-3). Polled up to 5 s,
    // so a loaded runner doesn't fail it (#36 R2-3).
    let deadline = ContinuousClock.now + .seconds(5)
    while played.count < 2 && ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(50))
    }
    #expect(played == [.directionUp, .retry])
  }

  @Test("FR-013 game, set, match and change of ends are four different patterns")
  func fourPatterns() {
    let types = [Haptic.game, .set, .match, .changeOfEnds].map(WatchHaptics.hapticType)
    #expect(Set(types.map(\.rawValue)).count == 4)
    #expect(WatchHaptics.hapticType(for: .point) == .click)
  }

  // MARK: Announcements (R4, US7 s2–s4)

  @Test("US7 s3 a game won announces \"Game: Me\"")
  func announceGame() {
    #expect(feedback(makeSession(), g(1, .me) + "MMM", last: "M").announcements == ["Game: Me"])
  }

  @Test("US7 s3 a set won announces \"Set: Opponent\"")
  func announceSet() {
    let result = feedback(makeSession(), g(4, .me) + g(5, .opponent) + "OOO", last: "O")
    #expect(result.announcements == ["Set: Opponent"])
  }

  @Test("US7 s3 the match won announces \"Match: Me\" only")  // ITF: EN-05
  func announceMatch() {
    let session = makeSession(PointOutcomeTests.format(.oneSet))
    let result = feedback(session, g(5, .me) + g(3, .opponent) + "MMM", last: "M")
    #expect(result.announcements == ["Match: Me"])
  }

  @Test("R4 a change-of-ends game point yields exactly one \"Game: Me. Change ends\"")  // ITF: EN-01
  func oneCombinedAnnouncement() {
    #expect(feedback(makeSession(), "MMM", last: "M").announcements == ["Game: Me. Change ends"])
  }

  @Test("US7 s4 a change-of-ends point that wins no game announces \"Change ends\"")  // ITF: TB-05
  func announceChangeEnds() {
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    #expect(feedback(makeSession(), toSixAll + "MMMOO", last: "O").announcements == ["Change ends"])
  }

  @Test("US7 s2 the status is announced when it appears")  // ITF: GM-02, TB-01
  func announceStatus() {
    #expect(feedback(makeSession(), "MMMOO", last: "O").announcements == ["Deuce"])
    // Advantage empties the status line: nothing to announce.
    #expect(feedback(makeSession(), "MMMOOO", last: "M").announcements.isEmpty)
    // A game that starts a tie-break: one announcement with both parts.
    let toSixFive = g(5, .me) + g(5, .opponent) + g(1, .me) + "OOO"
    #expect(
      feedback(makeSession(), toSixFive, last: "O").announcements == ["Game: Opponent. Tie-break"])
  }

  @Test("R4 a point with nothing to say announces nothing")
  func silentPoint() {
    #expect(feedback(makeSession(), "", last: "M").announcements.isEmpty)
  }

  @Test("US7 s2 undo announces only a status change")  // ITF: GM-02
  func undoAnnouncesStatus() {
    let session = makeSession()
    tap("MMMOOOM", on: session)  // advantage Me: empty status
    announcer.reset()
    session.undo()  // back to deuce
    #expect(announcer.announcements == ["Deuce"])
    announcer.reset()
    session.undo()  // 40–30: empty status
    #expect(announcer.announcements.isEmpty)
  }

  // MARK: Controls (US3 s7, US4 s10, FR-008)

  @Test(
    "US3 s7 pause, resume, correction and early end play no haptic; all but resume cancel a pending one"
  )
  func controlsPlayNoHaptic() {
    let session = makeSession()
    tap("MMMM", on: session)  // game 1: change of ends pending
    haptics.reset()
    session.pause()
    #expect(haptics.calls == [.cancelPending])
    session.resume()
    #expect(haptics.calls == [.cancelPending])
    session.correctServer()
    #expect(haptics.calls == [.cancelPending, .cancelPending])
    session.endEarly()
    #expect(haptics.calls == [.cancelPending, .cancelPending, .cancelPending])
    #expect(haptics.haptics.isEmpty)
    #expect(session.route == .summary)  // positive control: the commands ran
  }

  @Test("US4 s10 US7 s3 a correction announces the new server")  // ITF: CE-02
  func announceServer() {
    let session = makeSession()
    tap("M", on: session)
    announcer.reset()
    session.correctServer()
    #expect(announcer.announcements == ["Server: Opponent"])
    session.correctServer()
    #expect(announcer.announcements.last == "Server: Me")
  }

  @Test("FR-008 R1-3 pausing announces \"Paused\" with the game state; resume announces the state")  // ITF: GM-02
  func announcePause() {
    let session = makeSession()
    tap("MMMOOO", on: session)
    announcer.reset()
    session.pause()
    #expect(announcer.announcements == ["Paused. Deuce"])
    session.resume()
    #expect(announcer.announcements == ["Paused. Deuce", "Deuce"])
    let quiet = makeSession()
    announcer.reset()
    quiet.pause()
    quiet.resume()
    #expect(announcer.announcements == ["Paused"])
  }
}
