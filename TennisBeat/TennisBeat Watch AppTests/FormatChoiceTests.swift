import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// User Story 1 (New match), FR-001, FR-002, FR-004.
@MainActor
struct FormatChoiceTests {
  /// A throwaway `UserDefaults` suite per test.
  private func makeStore() -> FormatStore {
    let suite = "FormatChoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return FormatStore(defaults: defaults)
  }

  @Test("US1 s1 first use shows best of 3, sets of 6, Advantage, full third set (Q2)")
  func firstUseDefaults() {
    let choice = makeStore().load()
    #expect(choice.length == .bestOfThree)
    #expect(choice.setLength == .six)
    #expect(choice.atFortyAll == .advantage)
    #expect(choice.thirdSet == .fullSet)
  }

  @Test("US1 s3 the Third set row is hidden for 1 set and keeps its value")  // ITF: MT-02
  func thirdSetHiddenForOneSet() {
    var choice = FormatChoice()
    choice.thirdSet = .tieBreakToTen
    #expect(choice.isThirdSetVisible)
    choice.length = .oneSet
    #expect(!choice.isThirdSetVisible)
    #expect(choice.thirdSet == .tieBreakToTen)
    choice.length = .bestOfThree
    #expect(choice.isThirdSetVisible)
    #expect(choice.thirdSet == .tieBreakToTen)
  }

  @Test("US1 s5 save then load round-trips all four rows; no first server is stored")
  func roundTrip() throws {
    let store = makeStore()
    var choice = FormatChoice()
    choice.length = .oneSet
    choice.setLength = .four
    choice.atFortyAll = .decidingPoint
    choice.thirdSet = .tieBreakToTen
    store.save(choice)
    #expect(store.load() == choice)
    let stored = try #require(
      store.defaults.dictionary(forKey: FormatStore.key) as? [String: String])
    #expect(Set(stored.keys) == ["length", "setLength", "atFortyAll", "thirdSet"])
  }

  @Test(
    "US1 s6 an unknown or missing value falls back to its own default; other rows keep theirs",
    arguments: ["length", "setLength", "atFortyAll", "thirdSet"], [Optional("bogus"), nil])
  func perRowFallback(row: String, raw: String?) throws {
    let store = makeStore()
    var saved = FormatChoice()
    saved.length = .oneSet
    saved.setLength = .eight
    saved.atFortyAll = .decidingPoint
    saved.thirdSet = .tieBreakToTen
    store.save(saved)
    var stored = try #require(
      store.defaults.dictionary(forKey: FormatStore.key) as? [String: String])
    stored[row] = raw
    store.defaults.set(stored, forKey: FormatStore.key)

    var expected = saved
    switch row {
    case "length": expected.length = FormatChoice.defaults.length
    case "setLength": expected.setLength = FormatChoice.defaults.setLength
    case "atFortyAll": expected.atFortyAll = FormatChoice.defaults.atFortyAll
    default: expected.thirdSet = FormatChoice.defaults.thirdSet
    }
    #expect(store.load() == expected)
  }

  @Test("FR-002 a 1-set match never has the match tie-break")  // ITF: MT-02
  func oneSetHasNoMatchTieBreak() throws {
    var choice = FormatChoice()
    choice.length = .oneSet
    choice.thirdSet = .tieBreakToTen
    let format = try #require(choice.matchFormat)
    #expect(format.length == .oneSet)
    #expect(!format.matchTieBreak)
  }

  @Test("US1 s6 every combination builds a format")
  func everyCombinationBuilds() {
    #expect(FormatChoice.allCombinations.count == 24)
    for choice in FormatChoice.allCombinations {
      #expect(choice.matchFormat != nil, "\(choice)")
    }
  }

  @Test("US1 s6 a format that can't be built never starts a match")
  func invalidFormatNeverStarts() {
    let session = MatchSession(
      store: makeStore(), haptics: RecordingHaptics(), announcer: RecordingAnnouncer(),
      workout: FakeWorkoutService.denied(), now: Date.init, makeFormat: { _ in nil })
    session.start(firstServer: .me)
    #expect(session.route == .setup)
    #expect(session.match == nil)
    #expect(session.clock == nil)

    // Positive control: the same session with a buildable format starts.
    let control = MatchSession(
      store: makeStore(), haptics: RecordingHaptics(), announcer: RecordingAnnouncer(),
      workout: FakeWorkoutService.denied(), now: Date.init, makeFormat: { $0.matchFormat })
    control.start(firstServer: .me)
    #expect(control.route == .playing)
  }

  @Test(
    "FR-001 every choice maps to the engine format",
    arguments: FormatChoice.allCombinations)  // ITF: MT-01, MT-03, ST-04, ST-06, ST-07, GM-02, NA-01
  func mapsToEngine(choice: FormatChoice) throws {
    let format = try #require(choice.matchFormat)
    let length: MatchLength = choice.length == .oneSet ? .oneSet : .bestOfThree
    let setLength: SetLength =
      switch choice.setLength {
      case .four: .four
      case .six: .six
      case .eight: .eight
      }
    let scoring: GameScoring = choice.atFortyAll == .advantage ? .advantage : .noAd
    #expect(format.length == length)
    #expect(format.setLength == setLength)
    #expect(format.gameScoring == scoring)
    #expect(
      format.matchTieBreak == (choice.length == .bestOfThree && choice.thirdSet == .tieBreakToTen))
  }
}
