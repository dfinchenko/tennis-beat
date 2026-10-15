import XCTest

/// User Story 1: the Health onboarding before New match, with the fake workout service
/// (contract §1, §2; T014).
final class HealthOnboardingUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  private func launchOnboarding(_ language: String = "en") -> XCUIApplication {
    XCUIApplication.launched(
      ["-uiTestHealth", "shouldRequest", "-resetFormat"], language: language,
      readyElement: "health.onboarding.title")
  }

  @MainActor
  func testUS1s1s2OnboardingBeforeNewMatchWithItsTexts() {
    let app = launchOnboarding()
    XCTAssertTrue(app.element("health.onboarding").exists)
    XCTAssertFalse(app.element("setup.format").exists, "New match shows before the onboarding")
    let expected = [
      "health.onboarding.title": "Matches as workouts in Health",
      "health.onboarding.line.1": "Each match is saved as a tennis workout in the Health app.",
      "health.onboarding.line.2":
        "Heart rate and active energy are shown during and after the match.",
      "health.onboarding.line.3": "Data stays in Health. Tennis Beat sends nothing anywhere.",
      "health.onboarding.continue": "Continue",
      "health.onboarding.notNow": "Not now",
    ]
    for (id, text) in expected {
      let element = app.element(id)
      XCTAssertTrue(element.exists, "\(id) missing")
      XCTAssertEqual(element.label, text, id)
    }
  }

  /// Denys's design condition on #29 (comment 6203433908): at the default text size on the
  /// 40 mm watch, Continue is visible without scrolling, in every language.
  @MainActor
  func testDesignContinueVisibleWithoutScrollingAtDefaultSize() {
    for language in ["en", "pl", "uk"] {
      let app = launchOnboarding(language)
      XCTAssertTrue(
        app.isOnScreen("health.onboarding.continue"), "Continue off screen in \(language)")
      app.terminate()
    }
  }

  @MainActor
  func testUS1s3ContinueOpensNewMatch() {
    let app = launchOnboarding()
    app.tap("health.onboarding.continue", until: "setup.format")
    XCTAssertFalse(app.element("health.onboarding").exists)
  }

  @MainActor
  func testUS1s4NotNowOpensNewMatchAndTheOnboardingReturnsNextLaunch() {
    let app = launchOnboarding()
    app.tap("health.onboarding.notNow", until: "setup.format")
    XCTAssertFalse(app.element("health.onboarding").exists)
    app.terminate()

    // The fake keeps no state between launches: the sheet is still unanswered (Q4).
    let next = launchOnboarding()
    XCTAssertTrue(next.element("health.onboarding").exists)
  }

  @MainActor
  func testUS1s5NoOnboardingOnceTheSheetWasAnswered() {
    for mode in ["granted", "denied"] {
      let app = XCUIApplication.launched(["-uiTestHealth", mode])
      XCTAssertTrue(app.element("setup.format").exists, mode)
      XCTAssertFalse(app.element("health.onboarding").exists, mode)
      app.terminate()
    }
  }

  @MainActor
  func testUS1s6AfterNotNowAMatchStartsAsInSpec002() {
    let app = launchOnboarding()
    app.tap("health.onboarding.notNow", until: "setup.start")
    app.tap("setup.start", until: "firstServer.me")
    app.tap("firstServer.me", until: "zone.me")
    XCTAssertTrue(app.element("score.summary").exists)
  }
}
