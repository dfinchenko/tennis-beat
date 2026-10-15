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

  private(set) var mode: FakeHealthMode
  private(set) var calls: [Call] = []
  /// The statistics `statistics()` and `save` report (`-uiTestWorkoutStats`).
  var stats = WorkoutStatistics()
  var saveFails: Bool
  /// Replaces the mode's answer to `authorizationRequestStatus()`.
  var statusOverride: AuthorizationRequestStatus?
  /// Runs before `authorizationRequestStatus()` answers, so tests can hold the answer back.
  var beforeStatus: (() async -> Void)?
  var onEvent: ((WorkoutToken, WorkoutEvent) -> Void)?

  private let now: () -> Date
  private var answered: Bool

  init(mode: FakeHealthMode, now: @escaping () -> Date, saveFails: Bool = false) {
    self.mode = mode
    self.now = now
    self.saveFails = saveFails
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
    if mode == .failing { onEvent?(token, .failed) }
    return token
  }

  func pause() { calls.append(.pause(at: now())) }

  func resume() { calls.append(.resume(at: now())) }

  func statistics() -> WorkoutStatistics { stats }

  func save(endingAt date: Date) async throws -> SavedWorkout {
    calls.append(.save(endingAt: date))
    if saveFails { throw SaveFailed() }
    return SavedWorkout(uuid: UUID(), statistics: stats)
  }

  func discard() { calls.append(.discard(at: now())) }

  func recoverAndSave() async { calls.append(.recoverAndSave) }
}
