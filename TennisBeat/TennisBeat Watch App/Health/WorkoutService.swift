import Foundation

/// What `MatchSession` and the onboarding need from HealthKit (data-model § WorkoutService,
/// research R1). Production: `HealthKitWorkoutService`; tests and UI tests:
/// `FakeWorkoutService`. Nothing behind this protocol stores health data (FR-014).
protocol WorkoutService: AnyObject {
  /// `.shouldRequest` until the system sheet has been answered for the FR-003 types.
  func authorizationRequestStatus() async -> AuthorizationRequestStatus
  /// Shows the system sheet for the FR-003 types. Never fails to the caller.
  func requestAuthorization() async
  /// Saving workouts is authorized (research R3).
  var canStartWorkout: Bool { get }

  /// Starts a tennis workout with no location type (Q1), collecting from `date`.
  func start(at date: Date) -> WorkoutToken
  func pause()
  func resume()
  /// The workout's statistics so far (research R7).
  func statistics() -> WorkoutStatistics
  /// Ends and saves the current workout at `date`, or at HealthKit's last event if later
  /// (research R2). Also finishes a workout the system ended, with what it collected
  /// (#28 R6-4). The call takes the current workout before its first suspension.
  func save(endingAt date: Date) async throws -> SavedWorkout
  /// Ends the current workout without saving it (FR-008).
  func discard()
  /// FR-009a: saves a workout left running when the app was ended (research R10).
  func recoverAndSave() async

  /// Events of the workout with the given token (research R11).
  var onEvent: ((WorkoutToken, WorkoutEvent) -> Void)? { get set }
}

/// The system's answer to "has the permission sheet been answered?" (research R8).
nonisolated enum AuthorizationRequestStatus: Hashable, Sendable {
  case shouldRequest
  case unnecessary
  /// HealthKit couldn't tell; treated as `.unnecessary`, so an error never shows the
  /// onboarding on every launch.
  case unknown
}

/// Identifies one workout, so late callbacks from an earlier one are dropped (R11).
nonisolated struct WorkoutToken: Hashable, Sendable {
  let id = UUID()
}

nonisolated enum WorkoutEvent: Hashable, Sendable {
  case heartRate(HeartRateReading)
  /// The workout didn't start (FR-010).
  case failed
  /// The system ended the workout without the app asking (Story 2 s10).
  case endedUnexpectedly
}

nonisolated struct HeartRateReading: Hashable, Sendable {
  let bpm: Int
  let date: Date
}

nonisolated struct WorkoutStatistics: Hashable, Sendable {
  var averageHeartRate: Int?
  var maximumHeartRate: Int?
  /// Kilocalories.
  var activeEnergy: Double?
}

nonisolated struct SavedWorkout: Hashable, Sendable {
  let uuid: UUID
  let statistics: WorkoutStatistics
}

/// The workout as the session sees it (data-model § WorkoutState). In memory only.
nonisolated enum WorkoutState: Hashable, Sendable {
  /// No workout for this match: permission not given, or no match yet.
  case none
  case running
  case paused
  /// The summary is showing; the session is paused and the end date is fixed (research R2).
  case summary(openedAt: Date)
  /// A save started (Done or the 10-minute timeout); Undo is hidden (#28 R6-3).
  case saving
  case saved
  /// Ended with 0 points (FR-008).
  case discarded
  /// Didn't start, ended unexpectedly, or the timeout save failed: the match goes on as
  /// without a workout (FR-010, R3-2, #28 R6-4).
  case failed
}

/// The saved workout's end (research R2, #28 R5-2): HealthKit stamps `pause()` itself, a few
/// milliseconds after the clock, and every workout event must lie inside the workout.
nonisolated enum WorkoutEndDate {
  static func effective(requested: Date, eventDates: [Date]) -> Date {
    max(requested, eventDates.max() ?? requested)
  }
}
