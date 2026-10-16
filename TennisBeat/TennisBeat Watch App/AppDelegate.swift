import WatchKit

/// Hands a workout left running by an ended app to `WorkoutRecovery` (FR-009a, research R10).
final class AppDelegate: NSObject, WKApplicationDelegate {
  func handleActiveWorkoutRecovery() {
    let recovery = WorkoutRecovery(service: AppServices.workout)
    Task { await recovery.recover() }
  }
}
