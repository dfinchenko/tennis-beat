import Foundation

/// FR-009a: when watchOS relaunches the app with a workout still running, the workout is
/// finished at that moment and saved as it is (Q6, research R10). The match itself is lost
/// (crash recovery is spec 004), so the session stays on New match.
struct WorkoutRecovery {
  let service: WorkoutService

  func recover() async {
    await service.recoverAndSave()
  }
}
