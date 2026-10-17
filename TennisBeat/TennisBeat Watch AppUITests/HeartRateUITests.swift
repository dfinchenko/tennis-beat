import XCTest

/// The heart rate in the score header with the fake workout service (spec 003 Story 3,
/// FR-012; contract §1, §2; T039). "US3 s2" (no animation) is unit-tested in
/// HeartRateDisplayTests: UI tests can't see animations.
final class HeartRateUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  private func score(_ extra: [String]) -> XCUIApplication {
    let app = XCUIApplication.launched(["-resetFormat"] + extra)
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    return app
  }

  @MainActor
  func testUS3s1AReadingShowsInTheHeader() {
    let app = score(["-uiTestHealth", "granted", "-uiTestHeartRate", "142", "-uiTestExposeValues"])
    XCTAssertTrue(app.element("heartRate.value").waitForLabel("142"))
    XCTAssertEqual(app.element("heartRate").label, "Heart rate, 142 beats per minute")
  }

  @MainActor
  func testUS3s6VoiceOverReadsTheHeartRateWithTheElapsedTime() {
    // Without -uiTestExposeValues, as VoiceOver meets it: part of the elapsed time's value.
    let app = score(["-uiTestHealth", "granted", "-uiTestHeartRate", "142"])
    let elapsed = app.element("elapsed")
    XCTAssertTrue(elapsed.waitForValue("Heart rate, 142 beats per minute"))
    XCTAssertNotNil(elapsed.label.wholeMatch(of: /\d+:\d\d/), elapsed.label)
    XCTAssertFalse(app.element("heartRate").exists)  // not a separate stop
  }

  @MainActor
  func testUS3s3NoReadingShowsDashes() {
    let app = score(["-uiTestHealth", "granted", "-uiTestExposeValues"])
    XCTAssertTrue(app.element("heartRate.value").waitForLabel("--"))
    XCTAssertEqual(app.element("heartRate").label, "Heart rate unavailable")
  }

  @MainActor
  func testUS3s4NoRowWithoutAWorkout() {
    let app = score(["-uiTestHealth", "denied", "-uiTestHeartRate", "142", "-uiTestExposeValues"])
    XCTAssertTrue(app.element("elapsed").exists)  // positive control: the header is there
    XCTAssertFalse(app.element("heartRate").exists)
    XCTAssertFalse(app.element("heartRate.value").exists)
    XCTAssertEqual(app.element("elapsed").value as? String ?? "", "")
  }

  @MainActor
  func testUS3s5AlwaysOnHidesTheHeartRate() {
    let app = score([
      "-uiTestHealth", "granted", "-uiTestHeartRate", "142", "-uiTestExposeValues",
      "-uiTestAlwaysOn",
    ])
    XCTAssertTrue(app.element("elapsed").exists)
    XCTAssertFalse(app.element("heartRate").exists)
    XCTAssertFalse(app.element("heartRate.value").exists)
  }
}

extension XCUIElement {
  /// Waits until the element's accessibility value is `expected`.
  @MainActor
  func waitForValue(_ expected: String, timeout: TimeInterval = 5) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
    return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
  }
}
