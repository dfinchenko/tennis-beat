import XCTest

/// User Story 7 on the setup screens: labels, values and the accessibility audit (SC-005).
final class SetupAccessibilityUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  private func launch(_ arguments: [String] = ["-resetFormat"]) -> XCUIApplication {
    XCUIApplication.launched(arguments)
  }

  /// US7 s5: each row is one button whose label is the caption and whose value is the choice.
  @MainActor
  func testUS7s5RowsReadCaptionAndValue() {
    let app = launch()
    let expected: [(String, String, String)] = [
      ("setup.format", "Format", "Best of 3"),
      ("setup.setLength", "Set length", "6 games"),
      ("setup.atFortyAll", "At 40–40", "Advantage"),
      ("setup.thirdSet", "Third set", "Full set"),
    ]
    for (id, label, value) in expected {
      let row = app.buttons[id]
      XCTAssertTrue(row.waitForExistence(timeout: 5), "\(id) is not a button")
      XCTAssertEqual(row.label, label)
      XCTAssertEqual(row.value as? String, value)
    }
  }

  // SC-005: the accessibility audit passes on every setup screen. Each audit is the last
  // step of its test: on the watch simulator the app ignores taps after an audit.

  @MainActor
  func testSC005AuditNewMatch() throws {
    let app = launch()
    XCTAssertTrue(app.element("setup.start").waitForExistence(timeout: 5))
    try app.performAccessibilityAudit()
  }

  @MainActor
  func testSC005AuditPicker() throws {
    let app = launch()
    app.tap("setup.setLength", until: "picker.option.six")
    try app.performAccessibilityAudit()
  }

  @MainActor
  func testSC005AuditFirstServer() throws {
    let app = launch()
    app.tap("setup.start", until: "firstServer.coinToss")
    try app.performAccessibilityAudit()
  }

  @MainActor
  func testSC005AuditCoinTossResult() throws {
    let app = launch(["-resetFormat", "-coinToss", "me"])
    app.tap("setup.start", until: "firstServer.coinToss")
    app.tap("firstServer.coinToss", until: "coinToss.start")
    try app.performAccessibilityAudit()
  }
}
