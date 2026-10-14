import Foundation
import TennisCore
import XCTest

/// SC-002, User Story 2: every value on the score screen equals the engine's state after
/// every tap and every header Undo, in every format.
/// ITF: GM-01, GM-02, NA-01, NA-02, TB-01, TB-04, MT-03
final class ScoringUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Opens the score screen with `format` preselected through the `lastFormat.v1`
  /// defaults key (the argument domain overrides the stored value) and Me serving first.
  @MainActor
  private func startMatch(
    length: String = "bestOfThree", setLength: String = "six", atFortyAll: String = "advantage",
    thirdSet: String = "fullSet", exposeValues: Bool = true
  ) -> XCUIApplication {
    let format =
      "{length=\(length);setLength=\(setLength);atFortyAll=\(atFortyAll);thirdSet=\(thirdSet);}"
    let app = XCUIApplication.launched(
      ["-lastFormat.v1", format] + (exposeValues ? ["-uiTestExposeValues"] : []))
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    return app
  }

  // MARK: The R3-1 switch (research R7)

  @MainActor
  func testR7GuardZoneValuesOnlyWithExposeArgument() {
    let production = startMatch(exposeValues: false)
    XCTAssertTrue(production.element("zone.me").exists)
    XCTAssertEqual(production.element("zone.me").elementType, .button)
    XCTAssertFalse(production.element("zone.me.points").exists)
    XCTAssertTrue(production.element("score.summary").exists)
    production.terminate()

    let exposed = startMatch(exposeValues: true)
    XCTAssertTrue(exposed.element("zone.me.points").waitForExistence(timeout: 5))
    // The zone becomes a container around the button; it stays tappable.
    let zone = exposed.element("zone.me")
    XCTAssertTrue(zone.exists)
    XCTAssertTrue(zone.isHittable)
    XCTAssertEqual(zone.elementType, .other)
  }

  // MARK: Layout and header (US2 s1, s10)

  @MainActor
  func testUS2s1ZonesEqualFullWidthOpponentOnTop() {
    let app = startMatch()
    let opponent = app.element("zone.opponent").frame
    let me = app.element("zone.me").frame
    let window = app.windows.firstMatch.frame
    XCTAssertEqual(opponent.height, me.height, accuracy: 1)
    XCTAssertLessThan(opponent.maxY, me.midY, "Opponent is on top")
    for zone in [opponent, me] {
      XCTAssertGreaterThanOrEqual(
        zone.width, window.width * 0.9, "full width: \(zone) in \(window)")
    }
  }

  @MainActor
  func testUS2s10HeaderUndoAndElapsedNoHeartRate() throws {
    let app = startMatch()
    XCTAssertTrue(app.element("undo").exists)
    let elapsed = app.element("elapsed")
    XCTAssertTrue(elapsed.exists)
    let text = elapsed.label
    XCTAssertNotNil(
      text.range(of: #"^(\d{1,2}:)?\d{1,2}:\d{2}$"#, options: .regularExpression),
      "elapsed \(text)")
    let heart = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier CONTAINS[c] 'heart'"))
    XCTAssertEqual(heart.count, 0)
  }

  // MARK: Scripted sequences (SC-002)

  @MainActor
  func testSC002OneSetOfFourAdvantage() throws {
    try play(length: "oneSet", setLength: "four", atFortyAll: "advantage", seed: 1, taps: 60)
  }

  @MainActor
  func testSC002OneSetOfSixNoAd() throws {
    try play(length: "oneSet", setLength: "six", atFortyAll: "decidingPoint", seed: 2, taps: 60)
  }

  @MainActor
  func testSC002OneSetOfEightAdvantage() throws {
    try play(length: "oneSet", setLength: "eight", atFortyAll: "advantage", seed: 3, taps: 60)
  }

  @MainActor
  func testSC002BestOfThreeFullThirdSetNoAd() throws {
    try play(
      length: "bestOfThree", setLength: "four", atFortyAll: "decidingPoint", thirdSet: "fullSet",
      seed: 4, taps: 120, setup: Self.toOneSetAll(4))
  }

  @MainActor
  func testSC002BestOfThreeMatchTieBreakAdvantage() throws {
    try play(
      length: "bestOfThree", setLength: "six", atFortyAll: "advantage",
      thirdSet: "tieBreakToTen", seed: 5, taps: 50, setup: Self.toOneSetAll(6))
  }

  @MainActor
  func testSC002BestOfThreeMatchTieBreakNoAd() throws {
    try play(
      length: "bestOfThree", setLength: "eight", atFortyAll: "decidingPoint",
      thirdSet: "tieBreakToTen", seed: 6, taps: 50, setup: Self.toOneSetAll(8, tieBreak: true))
  }

  @MainActor
  func testSC002TieBreakSetAdvantage() throws {
    try play(
      length: "oneSet", setLength: "four", atFortyAll: "advantage", seed: 7, taps: 40,
      setup: Self.toTieBreak(4))
  }

  /// Sets at 1–1: Me wins set 1, Opponent set 2 (straight games, 4 points each).
  static func toOneSetAll(_ games: Int, tieBreak: Bool = false) -> [Player] {
    let me = [Player](repeating: .me, count: 4 * games)
    let opponent = [Player](repeating: .opponent, count: 4 * games)
    guard tieBreak else { return me + opponent }
    // Set 2 through a tie-break: N–N, then Opponent wins 7–0.
    return me + toTieBreak(games) + [Player](repeating: .opponent, count: 7)
  }

  /// A set to N–N (a tie-break), games alternating.
  static func toTieBreak(_ games: Int) -> [Player] {
    (0..<(2 * games)).flatMap { index in
      [Player](repeating: index.isMultiple(of: 2) ? .me : .opponent, count: 4)
    }
  }

  /// Taps `setup` checking every step, then `taps` seeded random taps with a header Undo
  /// every 7th step, comparing the screen with a replayed engine `Match` after each step.
  @MainActor
  private func play(
    length: String, setLength: String, atFortyAll: String, thirdSet: String = "fullSet",
    seed: UInt64, taps: Int, setup: [Player] = []
  ) throws {
    let format = try MatchFormat(
      length: length == "oneSet" ? .oneSet : .bestOfThree,
      setLength: SetLength(rawValue: ["four": 4, "six": 6, "eight": 8][setLength]!)!,
      gameScoring: atFortyAll == "advantage" ? .advantage : .noAd,
      matchTieBreak: length == "bestOfThree" && thirdSet == "tieBreakToTen")
    let app = startMatch(
      length: length, setLength: setLength, atFortyAll: atFortyAll, thirdSet: thirdSet)
    var match = Match(setup: MatchSetup(format: format, firstServer: .me))
    try check(app, match, step: "start")

    var generator = SeededGenerator(seed: seed)
    let random = (0..<taps).map { index -> Player? in
      index % 7 == 6 ? nil : (Bool.random(using: &generator) ? .me : .opponent)
    }
    for (index, action) in (setup.map(Optional.some) + random).enumerated() {
      guard match.state.status == .inProgress else { break }
      if let player = action {
        app.element("zone.\(player.rawValue)").tap()
        try match.recordPoint(wonBy: player, at: Date())
      } else {
        guard match.events.count > 1 else { continue }
        app.element("undo").tap()
        match.undo()
      }
      if match.state.status != .inProgress {
        // The match is won: the summary opens (US5 s1); its content is PR 4.
        XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
        return
      }
      try check(app, match, step: "step \(index) (\(action.map(\.rawValue) ?? "undo"))")
    }
  }

  /// Waits up to 3 s for the screen to show the engine's state, then compares.
  @MainActor
  private func check(_ app: XCUIApplication, _ match: Match, step: String) throws {
    let expected = ScreenReader.expected(match.state)
    var shown = ScreenReader.read(app)
    let deadline = Date().addingTimeInterval(3)
    while shown != expected && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      shown = ScreenReader.read(app)
    }
    XCTAssertEqual(shown, expected, step)
  }
}

/// SplitMix64, so each scripted sequence is the same on every run.
struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
