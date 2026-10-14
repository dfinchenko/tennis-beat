import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// `MatchSession`: routes and commands. Setup part (User Story 1).
@MainActor
struct SessionTests {
  private let clock = FakeClock()

  private func makeSession(_ store: FormatStore? = nil) -> MatchSession {
    MatchSession(
      store: store ?? makeStore(), haptics: RecordingHaptics(), announcer: RecordingAnnouncer(),
      now: clock.now)
  }

  private func makeStore() -> FormatStore {
    let suite = "SessionTests.\(UUID().uuidString)"
    return FormatStore(defaults: UserDefaults(suiteName: suite)!)
  }

  @Test("US1 s8 choosing a first server starts a 0–0 match on the score route")  // ITF: SV-01, SV-03
  func startOpensScore() throws {
    let session = makeSession()
    session.formatChoice.setLength = .four
    session.formatChoice.atFortyAll = .decidingPoint
    session.start(firstServer: .me)

    #expect(session.route == .playing)
    let match = try #require(session.match)
    #expect(match.events.count == 1)
    let expected = try #require(session.formatChoice.matchFormat)
    #expect(match.events.first == .setup(MatchSetup(format: expected, firstServer: .me)))
    #expect(match.state.points == PlayerPair(me: .zero, opponent: .zero))
    #expect(match.state.games == PlayerPair(me: 0, opponent: 0))
    #expect(match.state.server == .me)
    #expect(match.state.courtSide == .right)
    #expect(session.clock?.startedAt == clock.current)
    #expect(!session.isPaused)
  }

  @Test("US1 s5 starting a match stores its format for next time")
  func startStoresFormat() {
    let store = makeStore()
    let session = makeSession(store)
    session.formatChoice.length = .oneSet
    session.formatChoice.setLength = .eight
    #expect(store.load() == FormatChoice.defaults)  // positive control: nothing stored yet
    session.start(firstServer: .opponent)
    #expect(store.load() == session.formatChoice)
    // A new session (a relaunch) preselects it.
    #expect(makeSession(store).formatChoice == session.formatChoice)
  }

  @Test("US1 s10 no match exists before a first server is chosen")
  func noMatchBeforeStart() {
    let session = makeSession()
    #expect(session.route == .setup)
    #expect(session.match == nil)
    #expect(session.clock == nil)
  }

  @Test("US1 s10 tapping Coin toss again makes a new toss")  // ITF: SV-01
  func coinTossTossedAgain() {
    var tosses = 0
    let session = MatchSession(
      store: makeStore(), haptics: RecordingHaptics(), announcer: RecordingAnnouncer(),
      now: clock.now,
      coinToss: {
        tosses += 1
        return tosses.isMultiple(of: 2) ? .opponent : .me
      })
    #expect(tosses == 0)  // positive control: no toss before Coin toss is tapped
    #expect(session.tossCoin() == .me)
    #expect(session.tossCoin() == .opponent)
    #expect(tosses == 2)
    #expect(session.match == nil)
  }

  @Test("FR-022 elapsed time counts from the start")
  func elapsedFromStart() {
    let session = makeSession()
    session.start(firstServer: .me)
    clock.advance(by: 75)
    #expect(session.clock?.elapsed(at: clock.now()) == 75)
  }

  // MARK: Scoring (User Story 2, US4 header Undo)

  private func playing(
    _ format: MatchFormat = PointOutcomeTests.format(), firstServer: Player = .me
  ) -> MatchSession {
    let session = MatchSession(
      store: makeStore(), haptics: RecordingHaptics(), announcer: RecordingAnnouncer(),
      now: clock.now, makeFormat: { _ in format })
    session.start(firstServer: firstServer)
    return session
  }

  private func tap(_ points: String, on session: MatchSession) {
    for character in points where character != " " {
      session.addPoint(for: character == "M" ? .me : .opponent)
    }
  }

  @Test("US2 s2 a tap adds exactly one point for that player")
  func addPointAddsOne() throws {
    let session = playing()
    clock.advance(by: 12)
    session.addPoint(for: .me)
    let events = try #require(session.match?.events)
    #expect(events.count == 2)
    #expect(events.last == .point(winner: .me, recordedAt: clock.current))
    session.addPoint(for: .opponent)
    #expect(session.match?.events.last == .point(winner: .opponent, recordedAt: clock.current))
  }

  @Test("Edge: very fast taps add two points in order")
  func fastTaps() {
    let session = playing()
    session.addPoint(for: .opponent)
    session.addPoint(for: .me)
    let winners = session.match?.events.dropFirst().compactMap { event -> Player? in
      if case .point(let winner, _) = event { winner } else { nil }
    }
    #expect(winners == [.opponent, .me])
  }

  @Test("US2 s3 after the match is won a tap adds nothing")  // ITF: MT-08
  func noPointAfterWin() {
    let session = playing(PointOutcomeTests.format(.oneSet))
    tap(MatchScript.games(6, for: .me), on: session)
    let count = session.match?.events.count
    #expect(session.match?.state.status == .won(.me))
    #expect(!session.acceptsPoints)
    session.addPoint(for: .opponent)
    #expect(session.match?.events.count == count)
  }

  @Test("US2 s3 the match won opens the summary and stops the clock")
  func wonOpensSummary() {
    let session = playing(PointOutcomeTests.format(.oneSet))
    clock.advance(by: 60)
    tap(MatchScript.games(6, for: .opponent), on: session)
    #expect(session.route == .summary)
    clock.advance(by: 300)
    #expect(session.clock?.elapsed(at: clock.now()) == 60)
  }

  @Test("US2 s11 after any taps, undos, corrections and pauses the screen model equals the engine's")
  func modelMatchesEngine() throws {
    var rng = SplitMix64(seed: SplitMix64.testSeed)
    for format in FormatChoice.allCombinations.compactMap(\.matchFormat) {
      let session = playing(format)
      for _ in 0..<150 {
        switch UInt8.random(in: 0..<10, using: &rng) {
        case 0: session.undo()
        case 1, 2, 3: session.addPoint(for: .me)
        case 4, 5, 6: session.addPoint(for: .opponent)
        case 7: session.correctServer()
        case 8: session.pause()
        default: session.resume()
        }
        let match = try #require(session.match)
        let replayed = try Match(events: match.events)
        let paused = session.isPaused
        #expect(
          ScoreScreenModel(state: match.state, isPaused: paused, locale: Locale(identifier: "en"))
            == ScoreScreenModel(
              state: replayed.state, isPaused: paused, locale: Locale(identifier: "en")))
        #expect(match.state == replayed.state)
      }
    }
  }

  @Test("Edge: a language change rebuilds only the strings; the match is unaffected")
  func languageChange() throws {
    let session = playing()
    tap("MMO", on: session)
    let state = try #require(session.match?.state)
    let english = ScoreScreenModel(state: state, isPaused: false, locale: Locale(identifier: "en"))
    let ukrainian = ScoreScreenModel(state: state, isPaused: false, locale: Locale(identifier: "uk"))
    #expect(english.summaryAccessibilityLabel != ukrainian.summaryAccessibilityLabel)
    for player in Player.allCases {
      #expect(english[player].points == ukrainian[player].points)
      #expect(english[player].games == ukrainian[player].games)
      #expect(english[player].sets == ukrainian[player].sets)
      #expect(english[player].isServer == ukrainian[player].isServer)
    }
    #expect(session.match?.state == state)
  }

  @Test("US4 s2 header Undo removes the last event")
  func undoRemovesLast() throws {
    let session = playing()
    tap("MO", on: session)
    let before = try #require(session.match?.events)
    session.undo()
    #expect(session.match?.events == Array(before.dropLast()))
  }

  @Test("US4 s3 Undo is unavailable with only the setup")
  func cannotUndoSetup() {
    let session = playing()
    #expect(!session.canUndo)
    session.undo()
    #expect(session.match?.events.count == 1)
    session.addPoint(for: .me)
    #expect(session.canUndo)  // positive control
  }

  @Test(
    "US4 s4 undo across a game, a set and a match tie-break boundary restores score, server and side",
    arguments: [
      ("game", MatchScript.games(1, for: .me) + "MMM", "M"),
      ("set", MatchScript.games(5, for: .me) + "MMM", "M"),
      ("match tie-break", MatchScript.games(6, for: .me) + MatchScript.games(5, for: .opponent) + "OOO", "O"),
      ("match tie-break point", MatchScript.games(6, for: .me) + MatchScript.games(6, for: .opponent) + "MMMOO", "O"),
    ])  // ITF: SV-02, TB-02
  func undoAcrossBoundary(_ name: String, setup: String, last: String) throws {
    let session = playing(PointOutcomeTests.format(matchTieBreak: true))
    tap(setup, on: session)
    let before = try #require(session.match?.state)
    tap(last, on: session)
    #expect(session.match?.state != before, "\(name): the point changed nothing")
    session.undo()
    let after = try #require(session.match?.state)
    #expect(after == before, "\(name)")
    #expect(after.points == before.points)
    #expect(after.server == before.server)
    #expect(after.courtSide == before.courtSide)
  }

  // MARK: Controls (User Story 4)

  @Test("US4 s5 while paused no point is added")
  func pausedAddsNothing() {
    let session = playing()
    session.pause()
    #expect(session.isPaused)
    #expect(!session.acceptsPoints)
    session.addPoint(for: .me)
    #expect(session.match?.events.count == 1)
    session.resume()
    session.addPoint(for: .me)
    #expect(session.match?.events.count == 2)  // positive control
  }

  @Test("US4 s5 s6 the clock stops while paused and continues on resume")
  func pauseStopsClock() {
    let session = playing()
    clock.advance(by: 30)
    session.pause()
    clock.advance(by: 120)
    #expect(session.clock?.elapsed(at: clock.now()) == 30)
    session.resume()
    clock.advance(by: 10)
    #expect(session.clock?.elapsed(at: clock.now()) == 40)
  }

  @Test("US2 s3 after an early end a tap adds nothing")  // ITF: MT-08
  func noPointAfterEarlyEnd() {
    let session = playing()
    tap("M", on: session)
    session.endEarly()
    session.addPoint(for: .me)
    #expect(session.match?.events.last == .matchEndedEarly)
  }

  @Test("US4 s7 while paused Undo and Server work and keep the pause; End ends it")  // ITF: CE-02
  func pausedControls() {
    let session = playing()
    tap("MO", on: session)
    session.pause()
    session.undo()
    #expect(session.match?.events.count == 2)
    #expect(session.isPaused)
    session.correctServer()
    #expect(session.match?.events.last == .firstServerCorrected(.opponent))
    #expect(session.isPaused)
    session.endEarly()
    #expect(!session.isPaused)
    #expect(session.route == .summary)
    session.done()
    #expect(!session.isPaused)
    #expect(session.route == .setup)
  }

  @Test("US4 s9 Server records a correction; the score stays, server and side follow the engine")  // ITF: CE-02
  func correctServer() throws {
    let session = playing()
    tap("MMO", on: session)
    let before = try #require(session.match?.state)
    session.correctServer()
    let match = try #require(session.match)
    #expect(match.events.last == .firstServerCorrected(.opponent))
    #expect(match.effectiveFirstServer == .opponent)
    #expect(match.state.points == before.points)
    #expect(match.state.games == before.games)
    #expect(match.state.server == .opponent)
    #expect(match.state == (try Match(events: match.events)).state)
    session.correctServer()
    #expect(session.match?.events.last == .firstServerCorrected(.me))
  }

  @Test("US4 s9 Server works in a tie-break and while paused")  // ITF: CE-02, TB-02
  func correctServerInTieBreak() throws {
    let session = playing()
    tap(MatchScript.games(5, for: .me) + MatchScript.games(5, for: .opponent) + MatchScript.games(1, for: .me) + MatchScript.games(1, for: .opponent) + "MMM", on: session)
    #expect(session.match?.state.isTieBreak == true)
    session.pause()
    let before = try #require(session.match?.state)
    session.correctServer()
    let after = try #require(session.match?.state)
    #expect(after.points == before.points)
    #expect(after.isTieBreak)
    #expect(after.server != before.server)
  }

  @Test("US4 s12 End with a point ends the match early, stops the clock, opens the summary")  // ITF: MT-08
  func endEarlyWithPoint() {
    let session = playing()
    tap("M", on: session)
    clock.advance(by: 50)
    session.endEarly()
    #expect(session.match?.events.last == .matchEndedEarly)
    #expect(session.match?.state.status == .unfinished)
    #expect(session.route == .summary)
    clock.advance(by: 100)
    #expect(session.clock?.elapsed(at: clock.now()) == 50)
  }

  @Test("US4 s13 End with no point discards the match and opens New match")  // ITF: MT-08
  func endEarlyWithoutPoint() {
    let session = playing()
    session.endEarly()
    #expect(session.match == nil)
    #expect(session.clock == nil)
    #expect(session.route == .setup)
  }

  @Test("Edge: End after only undone points discards the match")
  func endEarlyAfterUndonePoints() {
    let session = playing()
    tap("MO", on: session)
    session.undo()
    session.undo()
    session.correctServer()  // a correction is not a point
    session.endEarly()
    #expect(session.match == nil)
    #expect(session.route == .setup)
  }

  @Test("Edge: pause and resume in a tie-break leave the tie-break, points, server and side unchanged")  // ITF: TB-02, TB-04
  func pauseInTieBreak() throws {
    let session = playing()
    tap(MatchScript.games(5, for: .me) + MatchScript.games(5, for: .opponent) + MatchScript.games(1, for: .me) + MatchScript.games(1, for: .opponent) + "MOM", on: session)
    let before = try #require(session.match?.state)
    #expect(before.isTieBreak)
    session.pause()
    #expect(session.match?.state == before)
    session.resume()
    let after = try #require(session.match?.state)
    #expect(after == before)
    #expect(after.points == before.points)
    #expect(after.server == before.server)
    #expect(after.courtSide == before.courtSide)
  }
}

