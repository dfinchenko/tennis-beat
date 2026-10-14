import XCTest

/// User Story 6 on the watch: the dimmed score screen (Watch 5, FR-021). `-uiTestAlwaysOn`
/// renders it as if the wrist were lowered; `-uiTestPoints` plays the points first, since
/// dimmed zones take no taps.
final class AlwaysOnUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  private func score(_ extra: [String]) -> XCUIApplication {
    let app = XCUIApplication.launched(["-resetFormat", "-uiTestExposeValues"] + extra)
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    return app
  }

  @MainActor
  func testUS6s1s2DimmedShowsMinutesOnly() {
    let app = score(["-uiTestAlwaysOn", "-uiTestPoints", "MMMOOO"])  // deuce
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("40"))
    let elapsed = app.element("elapsed").label
    XCTAssertNotNil(elapsed.wholeMatch(of: /\d+ min/), elapsed)
    // Q8: no Undo, no serve icon, no court-side pill.
    XCTAssertFalse(app.element("undo").exists)
    XCTAssertFalse(app.element("zone.me.serve").exists)
    XCTAssertFalse(app.element("zone.me.side").exists)
  }

  @MainActor
  func testUS6s1PositiveControlLitShowsSecondsUndoAndServe() {
    let app = score(["-uiTestPoints", "MMMOOO"])
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("40"))
    let elapsed = app.element("elapsed").label
    XCTAssertNotNil(elapsed.wholeMatch(of: /\d+:\d\d/), elapsed)
    XCTAssertTrue(app.element("undo").exists)
    XCTAssertTrue(app.element("zone.me.serve").exists)
    XCTAssertTrue(app.element("zone.me.side").exists)
  }

  @MainActor
  func testUS6s3DimmedZonesTakeNoTaps() {
    let app = score(["-uiTestAlwaysOn"])
    // A tap at the zone's centre, as a lowered wrist might touch it.
    app.element("zone.me").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertFalse(app.element("zone.me.points").waitForLabel("15", timeout: 2))
    XCTAssertEqual(app.element("zone.me.points").label, "0")
  }

  @MainActor
  func testUS6s3PositiveControlLitZonesTakeTaps() {
    let app = score([])
    app.element("zone.me").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(app.element("zone.me.points").waitForLabel("15"))
  }
}
