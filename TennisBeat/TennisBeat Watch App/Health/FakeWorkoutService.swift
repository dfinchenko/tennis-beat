import Foundation

/// The `-uiTestHealth` modes (contract §2).
nonisolated enum FakeHealthMode: String, Hashable, Sendable {
  /// The sheet was answered; workouts are not allowed.
  case denied
  /// The sheet was never answered; Continue answers it as `granted`.
  case shouldRequest
  /// The sheet was answered; workouts are allowed.
  case granted
  /// As `granted`, but the workout fails to start (Story 2 s9).
  case failing
}

/// An in-memory `WorkoutService` for unit tests and the DEBUG launch arguments. It records
/// every call with the time of the call from the injected clock, and never touches
/// HealthKit or any storage.
final class FakeWorkoutService: WorkoutService {
  enum Call: Hashable {
    case requestAuthorization
    case start(at: Date, token: WorkoutToken)
    case pause(at: Date)
    case resume(at: Date)
    case save(endingAt: Date)
    case discard(at: Date)
    case recoverAndSave
  }

  struct SaveFailed: Error {}

  /// Settable, so tests can change the permission in "Settings" (Story 5 s4).
  var mode: FakeHealthMode
  private(set) var calls: [Call] = []
  /// The dates HealthKit would stamp on its pause and resume events: the call's time plus
  /// `eventDelay` (research R2).
  private(set) var eventDates: [Date] = []
  /// The end each save used, after `WorkoutEndDate.effective` (#28 R5-2).
  private(set) var savedEndDates: [Date] = []
  /// How long after `now()` the fake stamps its pause and resume events.
  var eventDelay: TimeInterval = 0
  /// The workout started last.
  private(set) var currentToken: WorkoutToken?
  /// Runs inside `save` after the call is recorded, so tests can hold the save back.
  var beforeSaveReturns: (() async -> Void)?
  /// The statistics `statistics()` and `save` report (`-uiTestWorkoutStats`).
  var stats = WorkoutStatistics()
  /// What `save` reports instead of `stats`, as Health's finished workout may differ from the
  /// live snapshot (research R7).
  var savedStats: WorkoutStatistics?
  var saveFails: Bool
  /// With `saveFails`: only the next save fails; later saves work (`-uiTestSaveFails`).
  var saveFailsOnce = false
  /// Replaces the mode's answer to `authorizationRequestStatus()`.
  var statusOverride: AuthorizationRequestStatus?
  /// Runs before `authorizationRequestStatus()` answers, so tests can hold the answer back.
  var beforeStatus: (() async -> Void)?
  var onEvent: ((WorkoutToken, WorkoutEvent) -> Void)?
  /// `-uiTestHeartRate`: one reading of this many beats per minute when a workout starts.
  var heartRate: Int?

  private let now: () -> Date
  private var answered: Bool

  init(
    mode: FakeHealthMode, now: @escaping () -> Date, saveFails: Bool = false,
    heartRate: Int? = nil
  ) {
    self.mode = mode
    self.now = now
    self.saveFails = saveFails
    self.heartRate = heartRate
    answered = mode != .shouldRequest
  }

  func authorizationRequestStatus() async -> AuthorizationRequestStatus {
    await beforeStatus?()
    return statusOverride ?? (answered ? .unnecessary : .shouldRequest)
  }

  func requestAuthorization() async {
    calls.append(.requestAuthorization)
    if mode == .shouldRequest {
      answered = true
      mode = .granted
    }
  }

  var canStartWorkout: Bool { mode == .granted || mode == .failing }

  func start(at date: Date) -> WorkoutToken {
    let token = WorkoutToken()
    calls.append(.start(at: date, token: token))
    currentToken = token
    eventDates = []
    // Reported after `start` returns, as HealthKit does (research R3).
    if mode == .failing { Task { @MainActor in self.onEvent?(token, .failed) } }
    if mode == .granted, let heartRate {
      let reading = HeartRateReading(bpm: heartRate, date: now())
      Task { @MainActor in self.onEvent?(token, .heartRate(reading)) }
    }
    return token
  }

  func pause() {
    calls.append(.pause(at: now()))
    eventDates.append(now() + eventDelay)
  }

  func resume() {
    calls.append(.resume(at: now()))
    eventDates.append(now() + eventDelay)
  }

  func statistics() -> WorkoutStatistics { stats }

  func save(endingAt date: Date) async throws -> SavedWorkout {
    calls.append(.save(endingAt: date))
    let end = WorkoutEndDate.effective(requested: date, eventDates: eventDates)
    await beforeSaveReturns?()
    if saveFails {
      if saveFailsOnce { saveFails = false }
      throw SaveFailed()
    }
    savedEndDates.append(end)
    return SavedWorkout(uuid: UUID(), statistics: savedStats ?? stats)
  }

  func discard() { calls.append(.discard(at: now())) }

  func recoverAndSave() async { calls.append(.recoverAndSave) }

  /// How long the failing save of `-uiTestSaveFails` takes: long enough for New match to show
  /// first, so a UI test sees the notice come to it (research R5, T050).
  static let launchedSaveFailureDelay: Duration = .seconds(2)

  /// The fake for the DEBUG launch arguments (contract §2), or `nil` without `-uiTestHealth`.
  /// `-uiTestSaveFails`: the first save fails, `launchedSaveFailureDelay` after it starts;
  /// later saves work, so a second Done shows no notice.
  static func launched(
    _ options: LaunchOptions, now: @escaping () -> Date,
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) -> FakeWorkoutService? {
    guard let mode = options.healthMode else { return nil }
    let fake = FakeWorkoutService(
      mode: mode, now: now, saveFails: options.saveFails, heartRate: options.heartRate)
    if let stats = options.workoutStats { fake.stats = stats }
    if options.saveFails {
      fake.saveFailsOnce = true
      fake.beforeSaveReturns = { [weak fake] in
        guard fake?.saveFails == true else { return }
        try? await sleep(launchedSaveFailureDelay)
      }
    }
    return fake
  }

  /// Sends `event` as the workout with `token` (tests).
  func emit(_ event: WorkoutEvent, token: WorkoutToken) { onEvent?(token, event) }

  /// The system ends the current workout (Story 2 s10).
  func endUnexpectedly() {
    guard let currentToken else { return }
    onEvent?(currentToken, .endedUnexpectedly)
  }
}
