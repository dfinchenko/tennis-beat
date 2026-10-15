import Foundation
import HealthKit

/// The production `WorkoutService`. In this PR it covers the permission only (research R8);
/// the workout members are filled in with the workout lifecycle (003 PR 2, T028). Until
/// then the session never calls them (T010).
final class HealthKitWorkoutService: WorkoutService {
  /// FR-003: save workouts; read heart rate and active energy; nothing else.
  static let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
  static let typesToRead: Set<HKObjectType> = [
    HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
  ]

  private let store = HKHealthStore()
  var onEvent: ((WorkoutToken, WorkoutEvent) -> Void)?

  func authorizationRequestStatus() async -> AuthorizationRequestStatus {
    guard HKHealthStore.isHealthDataAvailable() else { return .unknown }
    do {
      let status = try await store.statusForAuthorizationRequest(
        toShare: Self.typesToShare, read: Self.typesToRead)
      switch status {
      case .shouldRequest: return .shouldRequest
      case .unnecessary: return .unnecessary
      default: return .unknown
      }
    } catch {
      return .unknown
    }
  }

  func requestAuthorization() async {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    // Whatever the answer, or an error, New match opens next (Story 1 s3).
    try? await store.requestAuthorization(toShare: Self.typesToShare, read: Self.typesToRead)
  }

  var canStartWorkout: Bool {
    store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
  }

  // MARK: Workout (003 PR 2)

  struct NotAvailable: Error {}

  func start(at date: Date) -> WorkoutToken { WorkoutToken() }
  func pause() {}
  func resume() {}
  func statistics() -> WorkoutStatistics { WorkoutStatistics() }
  func save(endingAt date: Date) async throws -> SavedWorkout { throw NotAvailable() }
  func discard() {}
  func recoverAndSave() async {}
}
