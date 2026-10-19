import XCTest

/// The summary's Health rows and the save-failure notice with the fake workout service
/// (spec 003 Story 4 s1–s3, s7, Story 2 s9; FR-013, FR-015; contract §1, §2; T050). The texts
/// in PL and UK and the plural forms are unit-tested in SummaryHealthRowsTests.
final class SummaryHealthUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// 16 straight points win a 1-set match of 4-game sets 4–0.
  static let format = "{length=oneSet;setLength=four;atFortyAll=advantage;thirdSet=fullSet;}"
  static let winningPoints = String(repeating: "M", count: 16)

  /// Launches with `health` (and `extra`), starts a match whose points are played at once, and
  /// waits for the summary.
  @MainActor
  private func summary(_ health: String, _ extra: [String] = []) -> XCUIApplication {
    let app = XCUIApplication.launched(
      ["-lastFormat.v1", Self.format, "-uiTestHealth", health, "-uiTestPoints", Self.winningPoints]
        + extra)
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "summary.done")
    return app
  }

  @MainActor
  func testUS4s1TheSummaryShowsHeartRateAndEnergyAfterDuration() {
    let app = summary("granted", ["-uiTestWorkoutStats", "138,171,612"])
    let heartRate = app.element("summary.heartRate")
    let energy = app.element("summary.energy")
    XCTAssertTrue(heartRate.waitForExistence(timeout: 5))
    XCTAssertEqual(heartRate.label, "Heart rate: average 138, maximum 171 beats per minute")
    XCTAssertEqual(energy.label, "Active energy: 612 kilocalories")
    // Contract §3: title, chips, Duration, Heart rate, Active energy, Done.
    let duration = app.element("summary.duration")
    XCTAssertLessThan(duration.frame.minY, heartRate.frame.minY)
    XCTAssertLessThan(heartRate.frame.minY, energy.frame.minY)
    XCTAssertLessThan(energy.frame.minY, app.element("summary.done").frame.minY)
    for row in [duration, heartRate, energy] {
      XCTAssertGreaterThanOrEqual(row.frame.height, 44, row.identifier)
    }
  }

  @MainActor
  func testUS4s2NoEnergyValueHidesTheEnergyRow() {
    let app = summary("granted", ["-uiTestWorkoutStats", "138,171,"])
    XCTAssertTrue(app.element("summary.heartRate").waitForExistence(timeout: 5))
    XCTAssertFalse(app.element("summary.energy").exists)
  }

  @MainActor
  func testUS4s2NoHeartRateHidesTheHeartRateRow() {
    let app = summary("granted", ["-uiTestWorkoutStats", ",,612"])
    XCTAssertTrue(app.element("summary.energy").waitForExistence(timeout: 5))
    XCTAssertFalse(app.element("summary.heartRate").exists)
  }

  @MainActor
  func testUS4s3WithoutAWorkoutTheSummaryShowsDurationOnly() {
    let app = summary("denied", ["-uiTestWorkoutStats", "138,171,612"])
    XCTAssertTrue(app.element("summary.duration").exists)  // positive control
    XCTAssertFalse(app.element("summary.heartRate").exists)
    XCTAssertFalse(app.element("summary.energy").exists)
  }

  @MainActor
  func testUS2s9AWorkoutThatFailedToStartShowsDurationOnly() {
    let app = summary("failing", ["-uiTestWorkoutStats", "138,171,612"])
    XCTAssertTrue(app.element("summary.duration").exists)
    XCTAssertFalse(app.element("summary.heartRate").exists)
    XCTAssertFalse(app.element("summary.energy").exists)
  }

  /// The notice's title and OK. watchOS may drop the identifiers of an alert's parts, so they
  /// are found by their labels too (contract §1).
  @MainActor
  private func notice(_ app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier == 'health.saveFailed' OR label == 'Workout not saved to Health'")
    ).firstMatch
  }

  @MainActor
  private func noticeOK(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "identifier == 'health.saveFailed.ok' OR label == 'OK'")
    ).firstMatch
  }

  @MainActor
  func testUS4s7AFailedSaveShowsTheNoticeOnceOnNewMatch() {
    // `-uiTestSaveFails`: the first save fails 2 s after Done; later saves work (contract §2).
    let app = summary("granted", ["-uiTestWorkoutStats", "138,171,612", "-uiTestSaveFails"])
    app.tap("summary.done", until: "setup.format")
    // New match is already showing when the save fails (R5): the notice comes to it.
    XCTAssertFalse(notice(app).exists)
    XCTAssertTrue(notice(app).waitForExistence(timeout: 10))
    noticeOK(app).tap()
    app.waitUntilReady("setup.format")
    XCTAssertFalse(notice(app).exists)

    // The next match saves without a failure: no notice after its Done.
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    // 16 points win; the watch simulator can swallow a tap, so a few more are allowed.
    for _ in 0..<16 { app.element("zone.me").tap() }
    for _ in 0..<4 where !app.element("summary.done").waitForExistence(timeout: 2) {
      app.element("zone.me").tap()
    }
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    app.tap("summary.done", until: "setup.format")
    XCTAssertFalse(notice(app).waitForExistence(timeout: 4))  // longer than the 2 s failure
  }
}
