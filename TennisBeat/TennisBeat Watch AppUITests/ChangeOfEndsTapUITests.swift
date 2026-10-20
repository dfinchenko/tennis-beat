import Foundation
import TennisCore
import XCTest

/// Spec 002 FR-012, Story 2 s2, Story 4 s2: a tap made while the change-of-ends haptic is still
/// pending counts like any other, whether it is a point or Undo (Denys, after #35: two of the
/// four recorded lost taps came while that haptic was pending). `-uiTestHoldChangeOfEnds`
/// keeps the haptic pending until the next command plays or drops it, so each tap below lands
/// while it is pending, with no race against the 0.8 s (spec 002 contract §2).
/// ITF: EN-01
final class ChangeOfEndsTapUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// One set of four, games alternating Me, Opponent, so ends change after games 1, 3, 5
  /// and 7. After each change of ends the next tap comes at once (as in the lost tap on
  /// `main`), after 2 s (past the usual 0.8 s), or is Undo after 2 s (as on #30).
  @MainActor
  func testTapsCountWhileTheChangeOfEndsHapticIsPending() throws {
    let format = "{length=oneSet;setLength=four;atFortyAll=advantage;thirdSet=fullSet;}"
    let app = XCUIApplication.launched(
      ["-lastFormat.v1", format, "-uiTestExposeValues", "-uiTestHoldChangeOfEnds"])
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    var match = Match(
      setup: MatchSetup(
        format: try MatchFormat(
          length: .oneSet, setLength: .four, gameScoring: .advantage, matchTieBreak: false),
        firstServer: .me))

    var step = 0
    func point(_ player: Player) throws {
      app.element("zone.\(player.rawValue)").tap()
      try match.recordPoint(wonBy: player, at: Date())
      step += 1
      try check(app, match, step: "step \(step) (\(player.rawValue))")
    }

    var changes = 0
    for game in 0..<7 {
      let winner: Player = game.isMultiple(of: 2) ? .me : .opponent
      for _ in 0..<4 { try point(winner) }
      guard match.state.changeOfEnds else { continue }
      changes += 1
      switch changes {
      case 1:
        break  // the next game's first tap at once
      case 2:
        RunLoop.current.run(until: Date().addingTimeInterval(2))
      default:
        // Undo while pending, then the game point again (a change of ends again).
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        app.element("undo").tap()
        match.undo()
        try check(app, match, step: "undo after game \(game + 1)")
        try point(winner)
        if changes == 4 { RunLoop.current.run(until: Date().addingTimeInterval(2)) }
      }
    }
    XCTAssertEqual(changes, 4)
    try point(.me)  // the first point of the tie-break, after a 2 s hold
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
