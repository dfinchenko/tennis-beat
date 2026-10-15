import XCTest

/// The final SC-005 pass (T072, Story 7 s6, s7): the accessibility audit on every screen of
/// the match flow in PL and UK, and in EN at the largest accessibility size. The EN audits
/// at the other size are in each screen's own tests (setup at the default size; Score,
/// Controls, the End confirmation and Summary at the largest accessibility size), so they
/// are not repeated here. On the watch simulator the app ignores taps after an audit, so
/// each audit gets its own launch.
final class AccessibilityAuditUITests: XCTestCase {
  private enum Screen: CaseIterable {
    case newMatch, picker, firstServer, coinTossResult, score, controls, endConfirmation, summary

    var isSetup: Bool { [.newMatch, .picker, .firstServer, .coinTossResult].contains(self) }
  }

  private struct Setting {
    let language: String
    let size: String?
    var name: String { language + (size == nil ? "" : " AX XXXL") }
  }

  override func setUp() {
    continueAfterFailure = true
  }

  /// PL and UK at the default size and at the largest accessibility size on every screen
  /// (#24 R1-3, R2-1); the score screen stops at XXXL (Q9). EN at the largest accessibility
  /// size for the setup screens only: the match screens already audit it in EN.
  private func settings(for screen: Screen) -> [Setting] {
    let largest = ScoreAccessibilityUITests.largestAccessibility
    var all = [Setting(language: "pl", size: nil), Setting(language: "uk", size: nil)]
    if screen.isSetup {
      all.append(Setting(language: "en", size: largest))
    }
    all += [Setting(language: "pl", size: largest), Setting(language: "uk", size: largest)]
    return all
  }

  /// Opens `screen` in a fresh launch. A 1-set match of 4-game sets keeps the summary short.
  @MainActor
  private func open(_ screen: Screen, _ setting: Setting) -> XCUIApplication {
    let format = "{length=oneSet;setLength=four;atFortyAll=advantage;thirdSet=fullSet;}"
    var arguments = ["-lastFormat.v1", format, "-coinToss", "me"]
    if let size = setting.size { arguments += ["-UIPreferredContentSizeCategoryName", size] }
    let app = XCUIApplication.launched(arguments, language: setting.language)
    switch screen {
    case .newMatch:
      break
    case .picker:
      app.tap("setup.setLength", until: "picker.option.four")
    case .firstServer:
      app.tap("setup.start", until: "firstServer.coinToss")
    case .coinTossResult:
      app.tap("setup.start", until: "firstServer.coinToss")
      app.tap("firstServer.coinToss", until: "coinToss.start")
    case .score, .controls, .endConfirmation, .summary:
      app.tap("setup.start", until: "firstServer.me")
      app.tap("firstServer.me", until: "zone.me")
      switch screen {
      case .controls:
        app.showControls()
      case .endConfirmation:
        app.showControls()
        app.openEndConfirmation()
      case .summary:
        for _ in 0..<16 { app.element("zone.me").tap() }  // 4–0
        XCTAssertTrue(app.element("summary.done").waitForExistence(timeout: 5))
      default:
        break
      }
    }
    return app
  }

  @MainActor
  private func audit(_ screen: Screen) throws {
    for setting in settings(for: screen) {
      try XCTContext.runActivity(named: "\(screen) \(setting.name)") { _ in
        let app = open(screen, setting)
        try app.auditNamingElements()
        app.terminate()
      }
    }
  }

  /// Spec 003 US6 s1, s2 (SC-006): the Health onboarding in EN, PL and UK at the default
  /// size, the largest standard size and the largest accessibility size; it scrolls, so
  /// nothing may be clipped, and both buttons must be at least 44 pt tall.
  @MainActor
  func testUS6s1s2AuditHealthOnboarding() throws {
    let sizes: [String?] = [
      nil, ScoreAccessibilityUITests.largestStandard,
      ScoreAccessibilityUITests.largestAccessibility,
    ]
    for language in ["en", "pl", "uk"] {
      for size in sizes {
        try XCTContext.runActivity(named: "onboarding \(language) \(size ?? "default")") { _ in
          var arguments = ["-uiTestHealth", "shouldRequest"]
          if let size { arguments += ["-UIPreferredContentSizeCategoryName", size] }
          let app = XCUIApplication.launched(
            arguments, language: language, readyElement: "health.onboarding.continue")
          for id in ["health.onboarding.continue", "health.onboarding.notNow"] {
            let button = app.element(id)
            app.reveal(button)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "\(id) \(language)")
          }
          try app.auditNamingElements()
          app.terminate()
        }
      }
    }
  }

  @MainActor func testSC005AuditNewMatch() throws { try audit(.newMatch) }
  @MainActor func testSC005AuditPicker() throws { try audit(.picker) }
  @MainActor func testSC005AuditFirstServer() throws { try audit(.firstServer) }
  @MainActor func testSC005AuditCoinTossResult() throws { try audit(.coinTossResult) }
  @MainActor func testSC005AuditScore() throws { try audit(.score) }
  @MainActor func testSC005AuditControls() throws { try audit(.controls) }
  @MainActor func testSC005AuditEndConfirmation() throws { try audit(.endConfirmation) }
  @MainActor func testSC005AuditSummary() throws { try audit(.summary) }
}
