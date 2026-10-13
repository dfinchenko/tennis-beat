import Foundation

/// A clock the test moves by hand; inject `clock.now` as the session's `now`.
final class FakeClock {
  var current: Date

  init(_ start: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
    current = start
  }

  func now() -> Date { current }

  func advance(by seconds: TimeInterval) {
    current += seconds
  }
}
