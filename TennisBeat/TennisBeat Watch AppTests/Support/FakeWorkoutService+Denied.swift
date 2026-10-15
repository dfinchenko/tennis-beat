import Foundation

@testable import TennisBeat_Watch_App

extension FakeWorkoutService {
  /// The spec 002 state: the sheet was answered and workouts are not allowed, so a session
  /// behaves exactly as before spec 003 (SC-005).
  static func denied() -> FakeWorkoutService {
    FakeWorkoutService(mode: .denied, now: Date.init)
  }
}
