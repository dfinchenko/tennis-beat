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

  /// Spec 003 US3 s1 ([#31 L1](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6223261542))
  /// and US6 s2 ([#31 L2](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6237948677);
  /// T040) at the largest standard size on 40 mm in EN, PL and UK. In every phase of a match
  /// (ordinary games with Advantage or the deciding point, a tie-break, a match tie-break and a
  /// pause in it) the heart rate sits under the elapsed time, never beside it under the system
  /// clock; the status follows it on its line or moves below it, never overlapping; nothing
  /// leaves the screen. The zones stay at least 44 pt tall; they keep the spec 002 frames (no
  /// workout) unless the phase's status sits on its own line; and within a phase they don't move
  /// between points or when the reading changes ("--" or 205).
  ///
  /// CI budget ([Denys, relayed on #31](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6238799308)):
  /// by default only the worst case runs, UK with ♥ 205, in every phase. `LAYOUT_MATRIX=full`
  /// (the nightly workflow, PRs that change header or layout files, or
  /// `TEST_RUNNER_LAYOUT_MATRIX=full` locally) runs EN, PL and UK with ♥ 205 and "--".
  /// The check that the zones stay put when the reading changes (♥ 205 → "--") needs two
  /// readings, so it runs only with the full matrix (#32 R1-2).
  @MainActor
  func testUS6s2HeartRateFitsAndKeepsTheZones() {
    let fullMatrix = ProcessInfo.processInfo.environment["LAYOUT_MATRIX"] == "full"
    let languages = fullMatrix ? ["en", "pl", "uk"] : ["uk"]
    let readings: [String?] = fullMatrix ? ["205", nil] : ["205"]
    // Best of 3, sets of 4: 32 points reach 4–4 in set 1 (a tie-break, ITF: ST-07); Me wins
    // set 1 4–0 and the Opponent set 2 4–0 for the match tie-break (ITF: MT-03).
    func format(_ atFortyAll: String) -> String {
      "{length=bestOfThree;setLength=four;atFortyAll=\(atFortyAll);thirdSet=tieBreakToTen;}"
    }
    let toTieBreak = String(repeating: "MMMMOOOO", count: 4)
    let toMatchTieBreak = String(repeating: "M", count: 16) + String(repeating: "O", count: 16)
    /// A phase: the launch that reaches it and the points played in it, one sample after each.
    struct Phase {
      let name: String
      let atFortyAll: String
      let points: String
      let steps: [String]
      var pauses = false
    }
    let phases = [
      Phase(name: "games", atFortyAll: "advantage", points: "", steps: ["MMMOOO", "M", "O", "M"]),
      Phase(name: "deciding point", atFortyAll: "decidingPoint", points: "", steps: ["MMMOOO"]),
      Phase(name: "tie-break", atFortyAll: "advantage", points: toTieBreak, steps: ["MMO"]),
      Phase(
        name: "match tie-break", atFortyAll: "advantage", points: toMatchTieBreak, steps: ["MMO"]),
      Phase(
        name: "paused match tie-break", atFortyAll: "advantage", points: toMatchTieBreak,
        steps: [], pauses: true),
    ]
    for language in languages {
      XCTContext.runActivity(named: language) { _ in
        @MainActor func launch(_ phase: Phase, _ health: [String]) -> XCUIApplication {
          let app = XCUIApplication.launched(
            [
              "-lastFormat.v1", format(phase.atFortyAll), "-UIPreferredContentSizeCategoryName",
              Self.largestStandard, "-uiTestExposeValues",
            ] + (phase.points.isEmpty ? [] : ["-uiTestPoints", phase.points]) + health,
            language: language)
          app.tap("setup.start", until: "firstServer.me")
          app.tap("firstServer.me", until: "zone.me")
          if phase.pauses {
            app.showControls()
            app.tap("controls.pauseResume")
            app.showScore()
          }
          return app
        }
        /// The zone frames once a tapped zone's press animation has ended.
        @MainActor func zones(_ app: XCUIApplication) -> [CGRect] {
          var frames = ["zone.me", "zone.opponent"].map { app.element($0).frame }
          for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.2)
            let next = ["zone.me", "zone.opponent"].map { app.element($0).frame }
            if next == frames { break }
            frames = next
          }
          return frames
        }

        // Spec 002's layout: the same screen without a workout.
        let without = launch(phases[0], ["-uiTestHealth", "denied"])
        let baseline = zones(without)
        XCTAssertFalse(without.element("heartRate").exists)  // positive control
        without.terminate()

        for phase in phases {
          XCTContext.runActivity(named: "\(language) \(phase.name)") { _ in
            var samples: [[CGRect]] = []
            var statusOnItsOwnLine = false
            for reading in readings {
              let app = launch(
                phase,
                ["-uiTestHealth", "granted"] + (reading.map { ["-uiTestHeartRate", $0] } ?? []))
              // Paused shows "--" (US3 s3); otherwise the reading, or "--" without one.
              let expected = phase.pauses ? "--" : reading ?? "--"
              XCTAssertTrue(app.element("heartRate.value").waitForLabel(expected), expected)
              for step in [""] + phase.steps {
                for point in step {
                  app.element(point == "M" ? "zone.me" : "zone.opponent").tap()
                }
                let context = "\(phase.name) ♥\(expected) after \(step)"
                let heart = app.element("heartRate").frame
                let elapsed = app.element("elapsed").frame
                XCTAssertTrue(app.frame.contains(heart), "\(context) \(heart)")
                XCTAssertTrue(app.frame.contains(elapsed), "\(context) \(elapsed)")
                XCTAssertGreaterThanOrEqual(
                  heart.minY, elapsed.maxY - 1,
                  "under the elapsed time: \(context) \(heart) \(elapsed)")
                let status = app.element("status")
                if status.exists, !status.label.isEmpty {
                  XCTAssertTrue(app.frame.contains(status.frame), "\(context) \(status.frame)")
                  XCTAssertFalse(status.frame.intersects(heart), "\(context) \(status.frame)")
                  XCTAssertGreaterThanOrEqual(status.frame.minY, elapsed.maxY - 1, context)
                  if status.frame.minY >= heart.maxY - 1 { statusOnItsOwnLine = true }
                }
                let frames = zones(app)
                for frame in frames {
                  XCTAssertGreaterThanOrEqual(frame.height, 44, "\(context) \(frame)")
                }
                if let first = samples.first {
                  XCTAssertEqual(frames, first, "zones move within the phase: \(context)")
                }
                samples.append(frames)
              }
              app.terminate()
            }
            if !statusOnItsOwnLine {
              XCTAssertEqual(samples.first, baseline, "\(phase.name): the status fits beside")
            }
          }
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
