import XCTest

extension XCUIApplication {
  /// How long a cold launch may take before New match is ready (R1-1 of #18). A fresh
  /// parallel simulator clone can take well over 10 s.
  static let launchTimeout: TimeInterval = 20

  /// Launches with `arguments` in `language` (English unless stated) and returns once
  /// `readyElement` (by default the first New match row) is ready for taps.
  @MainActor
  static func launched(
    _ arguments: [String], language: String = "en", readyElement: String = "setup.format",
    file: StaticString = #filePath, line: UInt = #line
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      arguments + ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
    app.launch()
    app.waitUntilReady(readyElement, file: file, line: line)
    return app
  }

  /// Waits, with an explicit timeout and no fixed sleep, until `id` exists and is
  /// hittable: the app has finished launching and accepts taps.
  @MainActor
  func waitUntilReady(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element(id))
    let result = XCTWaiter().wait(for: [ready], timeout: Self.launchTimeout)
    XCTAssertEqual(
      result, .completed, "\(id) was not ready within \(Self.launchTimeout) s",
      file: file, line: line)
  }

  /// Any element with this accessibility identifier.
  @MainActor
  func element(_ id: String) -> XCUIElement {
    descendants(matching: .any)[id]
  }

  /// Scrolls until `target` lies fully on screen. `isHittable` alone is not enough on the
  /// watch simulator: it reports elements below the visible area as hittable.
  @MainActor
  func reveal(_ target: XCUIElement) {
    var swipes = 0
    while !(frame.contains(target.frame) && target.isHittable) && swipes < 6 {
      swipeUp()
      swipes += 1
    }
  }

  /// Taps `id` once.
  @MainActor
  func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
    let target = element(id)
    XCTAssertTrue(target.waitForExistence(timeout: 5), "\(id) not found", file: file, line: line)
    reveal(target)
    target.tap()
  }

  /// Taps `id` until `next` appears. The watch simulator can still swallow a single tap,
  /// so one retry is allowed.
  @MainActor
  func tap(
    _ id: String, until next: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    for _ in 0..<2 {
      tap(id, file: file, line: line)
      if element(next).waitForExistence(timeout: 3) { return }
    }
    XCTFail("\(next) did not appear after tapping \(id)", file: file, line: line)
  }
}

extension XCUIApplication {
  /// Runs the accessibility audit (all types) and fails once per issue, naming the element,
  /// so a failure says which element is wrong.
  @MainActor
  func auditNamingElements(file: StaticString = #filePath, line: UInt = #line) throws {
    try performAccessibilityAudit { issue in
      let element = issue.element.map {
        "\($0.elementType) '\($0.identifier)' \($0.frame) label '\($0.label)'"
      }
      XCTFail(
        "\(issue.compactDescription): \(element ?? "no element") — \(issue.detailedDescription)",
        file: file, line: line)
      return true  // reported above
    }
  }
}
