import XCTest

/// FR-025 / Q9 and SC-005 on the score screen. Audits run without `-uiTestExposeValues`
/// (research R7), and each audit is the last step of its test (taps fail after an audit).
final class ScoreAccessibilityUITests: XCTestCase {
  static let largestStandard = "UICTContentSizeCategoryXXXL"
  static let largestAccessibility = "UICTContentSizeCategoryAccessibilityXXXL"

  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  private func score(size: String, exposeValues: Bool) -> XCUIApplication {
    let app = XCUIApplication.launched(
      ["-resetFormat", "-UIPreferredContentSizeCategoryName", size]
        + (exposeValues ? ["-uiTestExposeValues"] : []))
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    return app
  }

  @MainActor
  func testFR025ScoreKeepsLargestStandardSizeAtAccessibilitySizes() {
    let standard = score(size: Self.largestStandard, exposeValues: true)
    XCTAssertTrue(standard.element("zone.me.points").waitForExistence(timeout: 5))
    let standardFrame = standard.element("zone.me.points").frame
    standard.terminate()

    let accessibility = score(size: Self.largestAccessibility, exposeValues: true)
    XCTAssertTrue(accessibility.element("zone.me.points").waitForExistence(timeout: 5))
    XCTAssertEqual(accessibility.element("zone.me.points").frame, standardFrame)
  }

  /// Spec 003 US6 s2, US3 s1 ([#31 L1](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6223261542);
  /// T040): a three-digit heart rate at the largest standard size on 40 mm in EN, PL and UK,
  /// at 0–0 and in the longest case (paused in a match tie-break). The heart rate sits under
  /// the elapsed time, never beside it under the system clock; the status follows it on its
  /// line or moves below it, never overlapping; nothing leaves the screen; and the zones keep
  /// the spec 002 frames (the same state without a workout).
  @MainActor
  func testUS6s2HeartRateFitsAndKeepsTheZones() {
    // Best of 3 with a match tie-break: Me wins set 1 4–0, the Opponent set 2 4–0.
    let format = "{length=bestOfThree;setLength=four;atFortyAll=advantage;thirdSet=tieBreakToTen;}"
    let toMatchTieBreak = String(repeating: "M", count: 16) + String(repeating: "O", count: 16)
    for language in ["en", "pl", "uk"] {
      for longest in [false, true] {
        XCTContext.runActivity(named: "\(language) \(longest ? "paused match tie-break" : "0–0")") {
          _ in
          @MainActor func launch(_ health: [String]) -> XCUIApplication {
            let app = XCUIApplication.launched(
              [
                "-lastFormat.v1", format, "-UIPreferredContentSizeCategoryName",
                Self.largestStandard, "-uiTestExposeValues",
              ] + (longest ? ["-uiTestPoints", toMatchTieBreak] : []) + health,
              language: language)
            app.tap("setup.start", until: "firstServer.me")
            app.tap("firstServer.me", until: "zone.me")
            if longest {
              app.showControls()
              app.tap("controls.pauseResume")
              app.showScore()
            }
            return app
          }
          let without = launch(["-uiTestHealth", "denied"])
          let zones = ["zone.me", "zone.opponent"].map { without.element($0).frame }
          XCTAssertFalse(without.element("heartRate").exists)  // positive control
          without.terminate()

          let app = launch(["-uiTestHealth", "granted", "-uiTestHeartRate", "205"])
          let value = app.element("heartRate.value")
          // Paused shows "--" (US3 s3); 0–0 shows the reading.
          XCTAssertTrue(value.waitForLabel(longest ? "--" : "205"))
          let heart = app.element("heartRate").frame
          let elapsed = app.element("elapsed").frame
          XCTAssertTrue(app.frame.contains(heart), "\(heart)")
          XCTAssertTrue(app.frame.contains(elapsed), "\(elapsed)")
          XCTAssertGreaterThanOrEqual(heart.minY, elapsed.maxY - 1, "under the elapsed time")
          if longest {
            let status = app.element("status")
            XCTAssertFalse(status.label.isEmpty)
            XCTAssertTrue(app.frame.contains(status.frame), "\(status.frame)")
            XCTAssertFalse(status.frame.intersects(heart), "\(status.frame) \(heart)")
            XCTAssertGreaterThanOrEqual(status.frame.minY, elapsed.maxY - 1)
          }
          XCTAssertEqual(["zone.me", "zone.opponent"].map { app.element($0).frame }, zones)
          app.terminate()
        }
      }
    }
  }

  /// Spec 003 US6 s2 (T040): the audit with the heart-rate row in EN, PL and UK at the largest
  /// standard size.
  @MainActor
  func testUS6s2AuditScoreWithHeartRate() throws {
    for language in ["en", "pl", "uk"] {
      try XCTContext.runActivity(named: language) { _ in
        let app = XCUIApplication.launched(
          [
            "-resetFormat", "-UIPreferredContentSizeCategoryName", Self.largestStandard,
            "-uiTestHealth", "granted", "-uiTestHeartRate", "205",
          ], language: language)
        app.tap("setup.start", until: "firstServer.me")
        app.tap("firstServer.me", until: "zone.me")
        XCTAssertTrue(app.element("elapsed").waitForValue(Self.spoken205[language]!))
        try app.auditNamingElements()
        app.terminate()
      }
    }
  }

  static let spoken205 = [
    "en": "Heart rate, 205 beats per minute",
    "pl": "Tętno, 205 uderzeń na minutę",
    "uk": "Пульс, 205 ударів на хвилину",
  ]

  @MainActor
  func testSC005AuditScoreLargestStandardSize() throws {
    try score(size: Self.largestStandard, exposeValues: false).auditNamingElements()
  }

  @MainActor
  func testSC005AuditScoreAccessibilitySize() throws {
    try score(size: Self.largestAccessibility, exposeValues: false).auditNamingElements()
  }
}
