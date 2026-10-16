import XCTest

/// Takes the PR screenshots of the setup, score, Controls and summary screens. Runs only when the test runner has
/// `SCREENSHOT_LANGUAGE` set (for example `TEST_RUNNER_SCREENSHOT_LANGUAGE=uk`), so CI skips it.
final class ScreenshotUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// Spec 003: the Health onboarding, top and bottom (watch-0-health-onboarding.md).
  @MainActor
  func testHealthOnboardingScreens() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let language = environment["SCREENSHOT_LANGUAGE"] else {
      throw XCTSkip("set SCREENSHOT_LANGUAGE to take screenshots")
    }
    var arguments = ["-uiTestHealth", "shouldRequest"]
    if let size = environment["SCREENSHOT_TEXT_SIZE"] {
      arguments += ["-UIPreferredContentSizeCategoryName", size]
    }
    let app = XCUIApplication.launched(
      arguments, language: language, readyElement: "health.onboarding.title")
    app.element("health.onboarding").swipeDown()
    attach(app, "0-health-onboarding")
    // Continue is pinned at the default size, so `reveal` sees Not now as on screen; drag the
    // text to its end instead.
    for _ in 0..<3 { app.dragUp() }
    attach(app, "0b-health-onboarding-bottom")
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

    var app = start(
      "{length=bestOfThree;setLength=four;atFortyAll=advantage;thirdSet=tieBreakToTen;}")
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

  /// T058: Controls, Paused at deuce (Controls and Score), and the End confirmation.
  @MainActor
  func testControlsScreens() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let language = environment["SCREENSHOT_LANGUAGE"] else {
      throw XCTSkip("set SCREENSHOT_LANGUAGE to take screenshots")
    }
    var arguments = ["-resetFormat"]
    if let category = environment["SCREENSHOT_TEXT_SIZE"] {
      arguments += ["-UIPreferredContentSizeCategoryName", category]
    }
    let app = XCUIApplication.launched(arguments, language: language)
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    for point in "MMMOOO" {
      app.element(point == "M" ? "zone.me" : "zone.opponent").tap()
    }
    app.showControls()
    attach(app, "12-controls")
    app.tap("controls.pauseResume")
    attach(app, "13-controls-paused")
    app.showScore()
    attach(app, "14-score-paused-deuce")
    app.showControls()
    app.openEndConfirmation()
    attach(app, "15-end-confirmation")
  }

  /// T068: Win, Loss, Match ended early and a match tie-break win.
  @MainActor
  func testSummaryScreens() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let language = environment["SCREENSHOT_LANGUAGE"] else {
      throw XCTSkip("set SCREENSHOT_LANGUAGE to take screenshots")
    }
    var size: [String] = []
    if let category = environment["SCREENSHOT_TEXT_SIZE"] {
      size = ["-UIPreferredContentSizeCategoryName", category]
    }
    func start(_ format: String) -> XCUIApplication {
      let app = XCUIApplication.launched(["-lastFormat.v1", format] + size, language: language)
      app.tap("setup.start", until: "firstServer.me")
      app.tap("firstServer.me", until: "zone.me")
      return app
    }
    func play(_ app: XCUIApplication, _ points: String) {
      for point in points where point != " " {
        app.element(point == "M" ? "zone.me" : "zone.opponent").tap()
      }
    }
    let oneSetOfFour = "{length=oneSet;setLength=four;atFortyAll=advantage;thirdSet=fullSet;}"
    let tieBreakToTen =
      "{length=bestOfThree;setLength=four;atFortyAll=advantage;thirdSet=tieBreakToTen;}"

    var app = start(oneSetOfFour)
    play(app, "MMMM OOOO MMMM MMMM MMMM")  // 4–1
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    attach(app, "16-summary-win")
    app.terminate()

    app = start(oneSetOfFour)
    play(app, "OOOO MMMM OOOO OOOO OOOO")  // 1–4
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    attach(app, "17-summary-loss")
    app.terminate()

    app = start(tieBreakToTen)
    play(app, "MMMM MMMM MMMM MMMM")  // set 1 Me 4–0
    play(app, "MMMM OOOO OOOO OOOO OOOO")  // set 2 Opponent 1–4
    play(app, "MMMM MMMM OOOO M")  // match tie-break at 9–4
    app.showControls()
    app.openEndConfirmation()
    app.endConfirmationButton.tap()
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    attach(app, "18-summary-ended-early")
    app.terminate()

    app = start(tieBreakToTen)
    play(app, "MMMM MMMM MMMM MMMM")  // set 1 Me 4–0
    play(app, "OOOO OOOO OOOO OOOO")  // set 2 Opponent 0–4
    play(app, String(repeating: "MO", count: 7) + "MMM")  // match tie-break 10–7
    XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
    attach(app, "19-summary-match-tie-break")
  }

  /// Spec 003 PR 2: the summary of a won match with a workout (paused, not yet saved, so Undo
  /// shows), and with a workout that failed to start (as in spec 002).
  @MainActor
  func testWorkoutSummaryScreens() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let language = environment["SCREENSHOT_LANGUAGE"] else {
      throw XCTSkip("set SCREENSHOT_LANGUAGE to take screenshots")
    }
    var size: [String] = []
    if let category = environment["SCREENSHOT_TEXT_SIZE"] {
      size = ["-UIPreferredContentSizeCategoryName", category]
    }
    let oneSetOfFour = "{length=oneSet;setLength=four;atFortyAll=advantage;thirdSet=fullSet;}"
    for (health, name) in [("granted", "20-summary-workout"), ("failing", "21-summary-workout-failed")] {
      let app = XCUIApplication.launched(
        ["-lastFormat.v1", oneSetOfFour, "-uiTestHealth", health] + size, language: language)
      app.tap("setup.start", until: "firstServer.me")
      app.tap("firstServer.me", until: "zone.me")
      for _ in 0..<16 { app.element("zone.me").tap() }
      XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
      app.reveal(app.element("summary.undo"))
      attach(app, name)
      app.terminate()
    }
  }

  /// Watch 5 next to `docs/design/screens/watch-5-always-on.png`: Me won the first set 6–4
  /// and leads 3–2, 30–15.
  @MainActor
  func testAlwaysOnScreens() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let language = environment["SCREENSHOT_LANGUAGE"] else {
      throw XCTSkip("set SCREENSHOT_LANGUAGE to take screenshots")
    }
    var size: [String] = []
    if let category = environment["SCREENSHOT_TEXT_SIZE"] {
      size = ["-UIPreferredContentSizeCategoryName", category]
    }
    let points =
      String(repeating: "OOOO", count: 4) + String(repeating: "MMMM", count: 6)  // 6–4
      + String(repeating: "OOOO", count: 2) + String(repeating: "MMMM", count: 3) + "MMO"
    for (name, alwaysOn) in [("20-always-on", true), ("21-score-lit", false)] {
      let app = XCUIApplication.launched(
        ["-resetFormat", "-uiTestPoints", points] + (alwaysOn ? ["-uiTestAlwaysOn"] : []) + size,
        language: language)
      app.tap("setup.start", until: "firstServer.me")
      app.tap("firstServer.me", until: "zone.me")
      // The points have been played once the summary reads 30–15 (or 15–30).
      let played = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "label CONTAINS '30' AND label CONTAINS '15'"),
        object: app.element("score.summary"))
      XCTAssertEqual(XCTWaiter().wait(for: [played], timeout: 10), .completed)
      attach(app, name)
      app.terminate()
    }
  }

  @MainActor
  private func attach(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
