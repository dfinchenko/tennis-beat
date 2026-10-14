import XCTest

/// User Story 4 on the watch: the Controls page, pause, server correction and End
/// (FR-014..FR-018). Value checks run with `-uiTestExposeValues`; the audits without it,
/// each as the last step of its test.
final class ControlsUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  private func score(_ extra: [String] = ["-uiTestExposeValues"]) -> XCUIApplication {
    let app = XCUIApplication.launched(["-resetFormat"] + extra)
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    return app
  }

  @MainActor
  private func label(_ app: XCUIApplication, _ id: String) -> String {
    app.element(id).label
  }

  // MARK: Navigation and labels (US4 s1, US7 s5)

  @MainActor
  func testUS4s1SwipeToControlsAndBack() {
    let app = score()
    app.showControls()
    XCTAssertTrue(app.isOnScreen("controls.elapsed"))
    for id in ["controls.undo", "controls.pauseResume", "controls.server", "controls.end"] {
      XCTAssertTrue(app.element(id).exists, id)
    }
    app.showScore()
    XCTAssertTrue(app.isOnScreen("zone.opponent"))
  }

  @MainActor
  func testUS7s5ControlLabelsAndUndoUnavailableAtStart() {
    let app = score([])
    app.showControls()
    XCTAssertEqual(label(app, "controls.undo"), "Undo")
    XCTAssertEqual(label(app, "controls.pauseResume"), "Pause")
    XCTAssertEqual(label(app, "controls.server"), "Server")
    XCTAssertEqual(label(app, "controls.end"), "End")
    // US4 s3: nothing to undo at 0–0.
    XCTAssertFalse(app.element("controls.undo").isEnabled)
  }

  /// #21 decision: on 40 mm at the default text size all four controls fit without
  /// scrolling, with round buttons of at least 48 pt (64 pt on larger watches).
  @MainActor
  func testControlsFitWithoutScrollingAtDefaultSize() throws {
    let app = score()
    app.showControls()
    let screen = app.frame
    for id in ["controls.undo", "controls.pauseResume", "controls.server", "controls.end"] {
      XCTAssertTrue(screen.contains(app.element(id).frame), "\(id) \(app.element(id).frame)")
    }
    let circle = app.element("controls.circle.end").frame
    XCTAssertGreaterThanOrEqual(circle.width, 48)
    XCTAssertLessThanOrEqual(circle.width, 64)
    if screen.width > 162 {  // larger than 40 mm
      XCTAssertEqual(circle.width, 64, accuracy: 0.5)
    }
  }

  // MARK: Undo (US4 s2, s3)

  @MainActor
  func testUS4s2UndoOnControlsRemovesLastPoint() {
    let app = score()
    app.element("zone.me").tap()
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("15"))
    app.showControls()
    XCTAssertTrue(app.element("controls.undo").isEnabled)
    app.tap("controls.undo")
    app.showScore()
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("0"))
  }

  // MARK: Pause (US4 s5, s6, FR-016)

  @MainActor
  func testUS4s5s6PauseStopsPointsAndResumeRestartsThem() {
    let app = score()
    app.showControls()
    app.tap("controls.pauseResume")
    XCTAssertTrue(app.element("controls.pauseResume").waitForLabel("Resume"))
    app.showScore()
    XCTAssertTrue(app.element("score.summary").label.hasSuffix(". Paused"))
    app.element("zone.me").tap()
    XCTAssertFalse(app.element("zone.me.points").waitForLabel("15", timeout: 2))

    app.showControls()
    app.tap("controls.pauseResume")
    XCTAssertTrue(app.element("controls.pauseResume").waitForLabel("Pause"))
    app.showScore()
    XCTAssertFalse(app.element("score.summary").label.contains("Paused"))
    app.element("zone.me").tap()
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("15"))
  }

  // MARK: Server (US4 s9)

  @MainActor
  func testUS4s9ServerMovesTheServeMarkAndKeepsThePoints() {  // ITF: CE-02
    let app = score()
    app.element("zone.me").tap()
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("15"))
    XCTAssertTrue(app.element("zone.me.serve").exists)
    app.showControls()
    app.tap("controls.server")
    app.showScore()
    XCTAssertTrue(app.element("zone.opponent.serve").waitForExistence(timeout: 3))
    XCTAssertFalse(app.element("zone.me.serve").exists)
    XCTAssertEqual(label(app, "zone.me.points"), "15")
    XCTAssertEqual(label(app, "zone.opponent.points"), "0")
  }

  // MARK: End (US4 s11..s13, US5 s3)

  @MainActor
  func testUS4s11EndCancelChangesNothing() {
    let app = score()
    app.element("zone.me").tap()
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("15"))
    app.showControls()
    app.openEndConfirmation()
    app.dismissEndConfirmation()
    XCTAssertTrue(app.element("controls.end").exists)
    app.showScore()
    XCTAssertEqual(label(app, "zone.me.points"), "15")
  }

  @MainActor
  func testUS4s12EndWithPointShowsMatchEndedEarly() {  // ITF: MT-08
    let app = score()
    app.element("zone.me").tap()
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("15"))
    app.showControls()
    app.openEndConfirmation()
    app.endConfirmationButton.tap()
    XCTAssertTrue(app.element("summary.title").waitForExistence(timeout: 5))
    XCTAssertEqual(label(app, "summary.title"), "Match ended early")
  }

  @MainActor
  func testUS4s13EndAtZeroOpensNewMatch() {  // ITF: MT-08
    let app = score()
    app.showControls()
    app.openEndConfirmation()
    app.endConfirmationButton.tap()
    XCTAssertTrue(app.element("setup.format").waitForExistence(timeout: 5))
    XCTAssertFalse(app.element("summary.title").exists)
  }

  // MARK: Audits (SC-005)

  @MainActor
  private func controls(size: String) -> XCUIApplication {
    let app = score(["-UIPreferredContentSizeCategoryName", size])
    app.showControls()
    return app
  }

  @MainActor
  func testSC005AuditControlsLargestStandardSize() throws {
    try controls(size: ScoreAccessibilityUITests.largestStandard).auditNamingElements()
  }

  @MainActor
  func testSC005AuditControlsAccessibilitySize() throws {
    try controls(size: ScoreAccessibilityUITests.largestAccessibility).auditNamingElements()
  }

  @MainActor
  func testSC005AuditEndConfirmationLargestStandardSize() throws {
    let app = controls(size: ScoreAccessibilityUITests.largestStandard)
    app.openEndConfirmation()
    try app.auditNamingElements()
  }

  @MainActor
  func testSC005AuditEndConfirmationAccessibilitySize() throws {
    let app = controls(size: ScoreAccessibilityUITests.largestAccessibility)
    app.openEndConfirmation()
    try app.auditNamingElements()
  }
}

extension XCUIApplication {
  /// The destructive "End match" action. watchOS drops accessibility identifiers on
  /// `confirmationDialog` actions, so the contract's `confirm.end` can't be set; the EN
  /// label finds it.
  @MainActor
  var endConfirmationButton: XCUIElement { buttons["End match"].firstMatch }

  /// The system Cancel of the confirmation (a Close button on watchOS).
  @MainActor
  var endConfirmationCancel: XCUIElement {
    buttons["AX_ActionContentControllerCancelButton"].firstMatch
  }

  /// Closes the confirmation with its system Cancel (Close). A tap that lands while the
  /// dialog is still animating in is swallowed (CI, #21), so it retries until the dialog
  /// has gone.
  @MainActor
  func dismissEndConfirmation(file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<3 {
      if endConfirmationCancel.exists { endConfirmationCancel.tap() }
      if endConfirmationCancel.waitForNonExistence(timeout: 3) { return }
    }
    XCTFail("the End confirmation did not close", file: file, line: line)
  }

  /// Taps End (scrolling to it) until the confirmation shows; one retry for a swallowed tap.
  @MainActor
  func openEndConfirmation(file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<2 {
      tap("controls.end", file: file, line: line)
      // The Close button's identifier doesn't depend on the language (screenshots run in PL, UK).
      if endConfirmationCancel.waitForExistence(timeout: 3) { return }
    }
    XCTFail("the End confirmation did not appear", file: file, line: line)
  }
}

extension XCUIElement {
  /// Waits up to `timeout` for the label to become `expected`.
  @MainActor
  func waitForLabel(_ expected: String, timeout: TimeInterval = 3) -> Bool {
    let match = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", expected), object: self)
    return XCTWaiter().wait(for: [match], timeout: timeout) == .completed
  }
}
