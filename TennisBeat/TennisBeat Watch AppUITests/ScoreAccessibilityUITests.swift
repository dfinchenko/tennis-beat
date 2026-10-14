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

  @MainActor
  func testSC005AuditScoreLargestStandardSize() throws {
    try score(size: Self.largestStandard, exposeValues: false).auditNamingElements()
  }

  @MainActor
  func testSC005AuditScoreAccessibilitySize() throws {
    try score(size: Self.largestAccessibility, exposeValues: false).auditNamingElements()
  }
}
