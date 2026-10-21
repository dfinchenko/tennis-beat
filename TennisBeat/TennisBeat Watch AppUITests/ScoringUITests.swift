import Foundation
import TennisCore
import XCTest

/// SC-002, User Story 2: every value on the score screen equals the engine's state after
/// every tap, header Undo and server correction, in every format. Each scripted sequence
/// plays its long part at launch and its last steps with real taps (#36).
/// ITF: GM-01, GM-02, NA-01, NA-02, TB-01, TB-04, MT-03
final class ScoringUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Opens the score screen with `format` preselected through the `lastFormat.v1`
  /// defaults key (the argument domain overrides the stored value) and Me serving first.
  /// `launchSteps` are played as the match opens (`-uiTestPoints`), with no taps.
  @MainActor
  private func startMatch(
    length: String = "bestOfThree", setLength: String = "six", atFortyAll: String = "advantage",
    thirdSet: String = "fullSet", exposeValues: Bool = true, launchSteps: String = ""
  ) -> XCUIApplication {
    let format =
      "{length=\(length);setLength=\(setLength);atFortyAll=\(atFortyAll);thirdSet=\(thirdSet);}"
    let app = XCUIApplication.launched(
      ["-lastFormat.v1", format] + (exposeValues ? ["-uiTestExposeValues"] : [])
        + (launchSteps.isEmpty ? [] : ["-uiTestPoints", launchSteps]))
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

  private enum Step {
    case point(Player)
    case undo
    case correctServer

    var name: String {
      switch self {
      case .point(let player): player.rawValue
      case .undo: "undo"
      case .correctServer: "server"
      }
    }

    /// The step in `-uiTestPoints` (spec 002 contract §2).
    var launchCode: Character {
      switch self {
      case .point(let player): player == .me ? "M" : "O"
      case .undo: "U"
      case .correctServer: "S"
      }
    }
  }

  /// How many of the last steps of each sequence are real taps (SC-002; Denys, relayed on #36:
  /// https://github.com/dfinchenko/tennis-beat/pull/36#issuecomment-6301821874 and on #37:
  /// https://github.com/dfinchenko/tennis-beat/pull/37#issuecomment-6310232479). The rest is
  /// played at launch: a synthesized tap is lost about once in 200 runs before it reaches the
  /// app (#36 repro), so fewer taps means fewer such failures. 12 steps always hold an Undo
  /// (every 7th) and a server correction (every 11th). `SC002_TAPS=all` (the nightly, or
  /// `TEST_RUNNER_SC002_TAPS=all` locally) taps every step: the full tap-by-tap coverage.
  static var realSteps: Int {
    ProcessInfo.processInfo.environment["SC002_TAPS"] == "all" ? .max : 12
  }

  /// `setup`, then `taps` seeded random steps: a header Undo every 7th step and a server
  /// correction on Controls every 11th. All but the last `realSteps` steps before the match
  /// ends are played at launch (none with `SC002_TAPS=all`); the screen is compared with a replayed engine `Match` once
  /// after them, and after each real tap, Undo and correction.  ITF: CE-02
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
    var generator = SeededGenerator(seed: seed)
    let random = (0..<taps).map { index -> Step in
      if index % 11 == 10 { return .correctServer }
      if index % 7 == 6 { return .undo }
      return .point(Bool.random(using: &generator) ? .me : .opponent)
    }

    // The steps that run, as the taps would: an Undo with nothing to undo is skipped, and
    // nothing runs after the winning point.
    var match = Match(setup: MatchSetup(format: format, firstServer: .me))
    var steps: [Step] = []
    for step in setup.map(Step.point) + random {
      guard match.state.status == .inProgress else { break }
      if case .undo = step, match.events.count <= 1 { continue }
      try Self.apply(step, to: &match)
      steps.append(step)
    }
    let real = steps.suffix(Self.realSteps)
    XCTAssertTrue(real.contains { if case .undo = $0 { true } else { false } }, "no Undo")
    XCTAssertTrue(
      real.contains { if case .correctServer = $0 { true } else { false } }, "no correction")

    let launched = steps.dropLast(real.count)
    let app = startMatch(
      length: length, setLength: setLength, atFortyAll: atFortyAll, thirdSet: thirdSet,
      launchSteps: String(launched.map(\.launchCode)))
    match = Match(setup: MatchSetup(format: format, firstServer: .me))
    for step in launched { try Self.apply(step, to: &match) }
    try check(app, match, step: "after \(launched.count) launch steps")

    for (offset, step) in real.enumerated() {
      switch step {
      case .point(let player):
        app.element("zone.\(player.rawValue)").tap()
      case .undo:
        app.element("undo").tap()
      case .correctServer:
        app.showControls()
        app.tap("controls.server")
        app.showScore()
      }
      try Self.apply(step, to: &match)
      if match.state.status != .inProgress {
        // The match is won: the summary opens (US5 s1).
        XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
        return
      }
      try check(app, match, step: "step \(launched.count + offset) (\(step.name))")
    }
  }

  private static func apply(_ step: Step, to match: inout Match) throws {
    switch step {
    case .point(let player): try match.recordPoint(wonBy: player, at: Date())
    case .undo: match.undo()
    case .correctServer: try match.correctFirstServer(to: match.effectiveFirstServer.other)
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
