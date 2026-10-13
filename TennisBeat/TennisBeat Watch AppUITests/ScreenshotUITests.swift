import XCTest

/// Takes the PR screenshots of the setup screens. Runs only when the test runner has
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
    var arguments = ["-resetFormat", "-coinToss", "opponent", "-AppleLanguages", "(\(language))"]
    arguments += ["-AppleLocale", language]
    if let size = environment["SCREENSHOT_TEXT_SIZE"] {
      arguments += ["-UIPreferredContentSizeCategoryName", size]
    }
    let app = XCUIApplication()
    app.launchArguments = arguments
    app.launch()

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

  @MainActor
  private func attach(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
