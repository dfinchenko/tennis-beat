import XCTest

/// User Story 5 on the watch: the summary after a win and after an early end, Undo and Done
/// (FR-019, FR-020). The audit runs as the last step of its test.
final class SummaryUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// A 1-set match of 4-game sets, Me serving first (`-coinToss me` through Coin toss).
  @MainActor
  private func score(_ extra: [String] = ["-uiTestExposeValues"]) -> XCUIApplication {
    let format = "{length=oneSet;setLength=four;atFortyAll=advantage;thirdSet=fullSet;}"
    let app = XCUIApplication.launched(["-lastFormat.v1", format, "-coinToss", "me"] + extra)
    app.tap("setup.start", until: "firstServer.coinToss")
    app.tap("firstServer.coinToss", until: "coinToss.start")
    app.tap("coinToss.start", until: "zone.me")
    return app
  }

  @MainActor
  private func play(_ app: XCUIApplication, _ points: String) {
    for point in points {
      app.element(point == "M" ? "zone.me" : "zone.opponent").tap()
    }
  }

  /// Wins 4–1: Me's points come straight, one game for the Opponent.
  @MainActor
  private func winMatch(_ app: XCUIApplication) {
    play(app, "MMMM" + "OOOO" + "MMMM" + "MMMM" + "MMM")
    if app.launchArguments.contains("-uiTestExposeValues") {
      XCTAssertTrue(app.element("zone.me.games").waitForLabel("3"))
    }
    play(app, "M")  // match point
  }

  @MainActor
  func testUS5s2s4s7WinShowsTitleChipsAndDuration() {
    let app = score()
    winMatch(app)
    XCTAssertTrue(app.element("summary.title").waitForExistence(timeout: 5))
    XCTAssertEqual(app.element("summary.title").label, "Win")
    XCTAssertEqual(app.element("summary.chip.1").label, "Set 1: 4–1, won")
    XCTAssertFalse(app.element("summary.chip.2").exists)
    XCTAssertTrue(app.element("summary.duration").exists)
  }

  @MainActor
  func testUS5s9UndoReturnsToMatchPoint() {
    let app = score()
    winMatch(app)
    app.tap("summary.undo", until: "zone.me")
    XCTAssertTrue(app.element("zone.me.games").waitForLabel("3"))
    XCTAssertEqual(app.element("zone.me.points").label, "40")
    XCTAssertEqual(app.element("zone.opponent.games").label, "1")
  }

  @MainActor
  func testUS5s3s5EndEarlyShowsUnfinishedChip() {  // ITF: MT-08
    let app = score()
    play(app, "MMMM" + "MMMM" + "OOOO" + "M")  // 2–1, 15–0
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("15"))
    app.showControls()
    app.openEndConfirmation()
    app.endConfirmationButton.tap()
    XCTAssertTrue(app.element("summary.title").waitForExistence(timeout: 5))
    XCTAssertEqual(app.element("summary.title").label, "Match ended early")
    XCTAssertEqual(app.element("summary.chip.1").label, "Set 1: 2–1, unfinished")
  }

  @MainActor
  func testUS5s10DoneOpensNewMatchWithTheFormatKept() {
    let app = score()
    winMatch(app)
    app.tap("summary.done", until: "setup.format")
    XCTAssertEqual(app.element("setup.format").value as? String, "1 set")
    XCTAssertEqual(app.element("setup.setLength").value as? String, "4 games")
  }

  @MainActor
  func testUS7s5SummaryButtonLabels() {
    let app = score([])
    winMatch(app)
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    XCTAssertEqual(app.element("summary.done").label, "Done")
    XCTAssertEqual(app.element("summary.undo").label, "Undo")
  }

  @MainActor
  func testSC005AuditSummaryAccessibilitySize() throws {
    let app = score([
      "-UIPreferredContentSizeCategoryName", ScoreAccessibilityUITests.largestAccessibility,
    ])
    winMatch(app)
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    try app.auditNamingElements()
  }
}
