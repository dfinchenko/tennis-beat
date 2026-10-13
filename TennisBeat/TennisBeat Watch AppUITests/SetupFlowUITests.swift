import XCTest

/// User Story 1 (New match, First server, coin toss) on the watch simulator, in English.
final class SetupFlowUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  private func launch(_ arguments: [String] = ["-resetFormat"], language: String = "en")
    -> XCUIApplication
  {
    XCUIApplication.launched(arguments, language: language)
  }

  @MainActor
  private func goBack(_ app: XCUIApplication, until next: String) {
    for _ in 0..<2 {
      let back = app.navigationBars.buttons.firstMatch
      XCTAssertTrue(back.waitForExistence(timeout: 5), "no back button")
      back.tap()
      if app.element(next).waitForExistence(timeout: 3) { return }
    }
    XCTFail("\(next) did not appear after going back")
  }

  @MainActor
  private func value(_ app: XCUIApplication, _ id: String) -> String {
    let row = app.element(id)
    XCTAssertTrue(row.waitForExistence(timeout: 5), "\(id) not found")
    return row.value as? String ?? ""
  }

  @MainActor
  private func choose(_ app: XCUIApplication, row: String, option: String) {
    app.tap(row, until: "picker.option.\(option)")
    app.tap("picker.option.\(option)", until: row)
  }

  /// US1 s1 and s2: four rows (caption above value) and Start, with the Q2 defaults.
  @MainActor
  func testUS1s1s2DefaultRows() {
    let app = launch()
    XCTAssertTrue(app.staticTexts["New match"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.element("setup.format").label, "Format")
    XCTAssertEqual(value(app, "setup.format"), "Best of 3")
    XCTAssertEqual(app.element("setup.setLength").label, "Set length")
    XCTAssertEqual(value(app, "setup.setLength"), "6 games")
    XCTAssertEqual(app.element("setup.atFortyAll").label, "At 40–40")
    XCTAssertEqual(value(app, "setup.atFortyAll"), "Advantage")
    XCTAssertEqual(app.element("setup.thirdSet").label, "Third set")
    XCTAssertEqual(value(app, "setup.thirdSet"), "Full set")
    XCTAssertTrue(app.element("setup.start").exists)
  }

  /// US1 s3: the Third set row hides for 1 set and returns with its previous value.  ITF: MT-02
  @MainActor
  func testUS1s3ThirdSetHiddenForOneSet() {
    let app = launch()
    choose(app, row: "setup.thirdSet", option: "tieBreakToTen")
    choose(app, row: "setup.format", option: "oneSet")
    XCTAssertFalse(app.element("setup.thirdSet").exists)
    choose(app, row: "setup.format", option: "bestOfThree")
    XCTAssertEqual(value(app, "setup.thirdSet"), "Tie-break to 10")
  }

  /// US1 s4: a row opens a picker with the current value selected; picking updates the row.
  @MainActor
  func testUS1s4PickerSelectsAndReturns() {
    let app = launch()
    app.tap("setup.setLength", until: "picker.option.six")
    let current = app.element("picker.option.six")
    XCTAssertTrue(current.waitForExistence(timeout: 5))
    XCTAssertTrue(current.isSelected)
    XCTAssertFalse(app.element("picker.option.eight").isSelected)
    app.tap("picker.option.eight", until: "setup.setLength")
    XCTAssertEqual(value(app, "setup.setLength"), "8 games")
  }

  /// US1 s5: the format of the last started match is preselected after a relaunch.
  @MainActor
  func testUS1s5FormatRememberedAfterRelaunch() {
    var app = launch()
    choose(app, row: "setup.atFortyAll", option: "decidingPoint")
    choose(app, row: "setup.setLength", option: "four")
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "score.placeholder")
    XCTAssertTrue(app.element("score.placeholder").waitForExistence(timeout: 5))
    app.terminate()

    app = launch([])
    XCTAssertEqual(value(app, "setup.atFortyAll"), "Deciding point")
    XCTAssertEqual(value(app, "setup.setLength"), "4 games")
  }

  /// US1 s7 and s8: Start asks who serves first; Me starts the match.  ITF: SV-01
  @MainActor
  func testUS1s7s8FirstServerStartsMatch() {
    let app = launch()
    app.tap("setup.start", until: "firstServer.me")
    XCTAssertTrue(app.staticTexts["Who serves first?"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.element("firstServer.me").label, "Me")
    XCTAssertEqual(app.element("firstServer.opponent").label, "Opponent")
    XCTAssertEqual(app.element("firstServer.coinToss").label, "Coin toss")
    app.tap("firstServer.me", until: "score.placeholder")
    XCTAssertTrue(app.element("score.placeholder").waitForExistence(timeout: 5))
  }

  /// US1 s9: the coin toss shows its result, and Start starts the match.  ITF: SV-01
  @MainActor
  func testUS1s9CoinTossResult() {
    let app = launch(["-resetFormat", "-coinToss", "opponent"])
    app.tap("setup.start", until: "firstServer.coinToss")
    app.tap("firstServer.coinToss", until: "coinToss.result")
    let result = app.element("coinToss.result")
    XCTAssertTrue(result.waitForExistence(timeout: 5))
    XCTAssertEqual(result.label, "First server: Opponent")
    app.tap("coinToss.start", until: "score.placeholder")
    XCTAssertTrue(app.element("score.placeholder").waitForExistence(timeout: 5))
  }

  /// US1 s10: going back never starts a match and keeps the settings.
  @MainActor
  func testUS1s10BackNavigation() {
    let app = launch(["-resetFormat", "-coinToss", "me"])
    choose(app, row: "setup.setLength", option: "eight")
    app.tap("setup.start", until: "firstServer.coinToss")
    goBack(app, until: "setup.setLength")
    XCTAssertEqual(value(app, "setup.setLength"), "8 games")

    app.tap("setup.start", until: "firstServer.coinToss")
    app.tap("firstServer.coinToss", until: "coinToss.result")
    goBack(app, until: "firstServer.coinToss")
    XCTAssertTrue(app.element("firstServer.coinToss").waitForExistence(timeout: 5))
    XCTAssertFalse(app.element("score.placeholder").exists)
  }

  /// US7 s7: an unsupported language shows English.
  @MainActor
  func testUS7s7OtherLanguageShowsEnglish() {
    let app = launch(["-resetFormat"], language: "de")
    XCTAssertTrue(app.staticTexts["New match"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.element("setup.start").label, "Start")
  }
}
