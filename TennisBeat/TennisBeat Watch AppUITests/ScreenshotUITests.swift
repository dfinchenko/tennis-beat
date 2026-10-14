import XCTest

/// Takes the PR screenshots of the setup and score screens. Runs only when the test runner has
/// `SCREENSHOT_LANGUAGE` set (for example `TEST_RUNNER_SCREENSHOT_LANGUAGE=uk`), so CI skips it.
final class ScreenshotUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testSetupScreens() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let language = environment["SCREENSHOT_LANGUAGE"] else {
      throw XCTSkip("set SCREENSHOT_LANGUAGE to take screenshots")
    }
    var arguments = ["-resetFormat", "-coinToss", "opponent"]
    if let size = environment["SCREENSHOT_TEXT_SIZE"] {
      arguments += ["-UIPreferredContentSizeCategoryName", size]
    }
    let app = XCUIApplication.launched(arguments, language: language)
    XCTAssertTrue(app.element("setup.start").waitForExistence(timeout: 5))
    attach(app, "1-new-match")

    app.tap("setup.setLength", until: "picker.option.six")
    attach(app, "2-picker-set-length")
    app.tap("picker.option.six", until: "setup.start")
    app.reveal(app.element("setup.start"))
    attach(app, "1b-new-match-bottom")

    app.tap("setup.start", until: "firstServer.coinToss")
    attach(app, "3-first-server")

    app.tap("firstServer.coinToss", until: "coinToss.start")
    attach(app, "4-coin-toss-result")
  }

  /// The score screen states T047 lists: 0–0, 30–15, deuce, the No-Ad deciding point, a
  /// tie-break, a match tie-break and two-digit tie-break points.
  @MainActor
  func testScoreScreens() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let language = environment["SCREENSHOT_LANGUAGE"] else {
      throw XCTSkip("set SCREENSHOT_LANGUAGE to take screenshots")
    }
    var size: [String] = []
    if let category = environment["SCREENSHOT_TEXT_SIZE"] {
      size = ["-UIPreferredContentSizeCategoryName", category]
    }
    func start(_ format: String) -> XCUIApplication {
      let app = XCUIApplication.launched(
        ["-lastFormat.v1", format] + size, language: language)
      app.tap("setup.start", until: "firstServer.me")
      app.tap("firstServer.me", until: "zone.me")
      return app
    }
    func play(_ app: XCUIApplication, _ points: String) {
      for point in points where point != " " {
        app.element(point == "M" ? "zone.me" : "zone.opponent").tap()
      }
    }
    let games = { (n: Int) in String(repeating: "MMMMOOOO", count: n) }  // n games each

    var app = start("{length=bestOfThree;setLength=four;atFortyAll=advantage;thirdSet=tieBreakToTen;}")
    attach(app, "5-score-0-0")
    play(app, "MMO")
    attach(app, "6-score-30-15")
    play(app, "MOO")
    attach(app, "7-score-deuce")
    play(app, "MM")  // advantage, then game Me: 1–0
    play(app, "OOOO" + games(3))  // to 4–4: a tie-break
    play(app, "MMO")
    attach(app, "9-score-tie-break")
    play(app, "MMMMM")  // tie-break 7–1: set 1 Me 5–4
    play(app, String(repeating: "OOOO", count: 4))  // set 2 Opponent 4–0: a match tie-break
    play(app, "MOM")
    attach(app, "10-score-match-tie-break")
    app.terminate()

    app = start("{length=oneSet;setLength=four;atFortyAll=decidingPoint;thirdSet=fullSet;}")
    play(app, "MMMOOO")
    attach(app, "8-score-deciding-point")
    play(app, "M" + "OOOO" + games(3))  // game Me, then to 4–4: a tie-break
    play(app, String(repeating: "MO", count: 11) + "M")  // 12–11
    attach(app, "11-score-tie-break-two-digits")
  }

  @MainActor
  private func attach(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
