import XCTest

/// Smoke tests of the workout path with the fake service (spec 003 Story 2; T033). The
/// lifecycle itself is unit-tested (WorkoutLifecycleTests, WorkoutSaveTests); the summary's
/// Health rows come in PR 4.
final class WorkoutUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// A 1-set match of 4-game sets, Me serving first.
  @MainActor
  private func score(_ health: String) -> XCUIApplication {
    let format = "{length=oneSet;setLength=four;atFortyAll=advantage;thirdSet=fullSet;}"
    let app = XCUIApplication.launched([
      "-lastFormat.v1", format, "-coinToss", "me", "-uiTestHealth", health,
    ])
    app.tap("setup.start", until: "firstServer.coinToss")
    app.tap("firstServer.coinToss", until: "coinToss.start")
    app.tap("coinToss.start", until: "zone.me")
    return app
  }

  /// Wins 4–0 with 16 straight points.
  @MainActor
  private func winMatch(_ app: XCUIApplication) {
    for _ in 0..<16 { app.element("zone.me").tap() }
  }

  @MainActor
  func testUS2s4s6WithAWorkoutTheSummaryOffersUndoAndDoneOpensNewMatch() {
    let app = score("granted")
    winMatch(app)
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    XCTAssertTrue(app.element("summary.undo").exists)
    app.tap("summary.done", until: "setup.format")
  }

  @MainActor
  func testUS2s9AFailedWorkoutLeavesTheMatchAsInSpec002() {
    let app = score("failing")
    winMatch(app)
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    XCTAssertTrue(app.element("summary.undo").exists)  // R3-2: no workout, Undo kept
    app.tap("summary.undo", until: "zone.me")
  }
}
