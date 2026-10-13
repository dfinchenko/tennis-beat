import XCTest

extension XCUIApplication {
  /// Launches with `arguments` in `language` (English unless stated).
  @MainActor
  static func launched(_ arguments: [String], language: String = "en") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      arguments + ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
    app.launch()
    return app
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

  /// Taps `id` until `next` appears. The watch simulator sometimes swallows a tap right after
  /// launch, so one retry is allowed.
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
