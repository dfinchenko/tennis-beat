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
}
