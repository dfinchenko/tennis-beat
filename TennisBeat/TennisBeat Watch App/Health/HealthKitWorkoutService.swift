import Foundation
import HealthKit

/// The production `WorkoutService`: the permission (research R8) and the tennis workout,
/// one `HKWorkoutSession` with its `HKLiveWorkoutBuilder` per match (research R2, R3, R11).
/// Nothing here stores health data; the builder saves the workout to Health (FR-014).
final class HealthKitWorkoutService: WorkoutService {
  /// FR-003: save workouts; read heart rate and active energy; nothing else.
  static let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
  static let typesToRead: Set<HKObjectType> = [
    HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
  ]

  /// Tennis, with no court type (Q1).
  static var configuration: HKWorkoutConfiguration {
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .tennis
    configuration.locationType = .unknown
    return configuration
  }

  private let store = HKHealthStore()
  /// The current match's workout. An earlier one finishes its save on its own (R11).
  private var current: LiveWorkout?
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

  // MARK: Workout

  struct NotAvailable: Error {}

  func start(at date: Date) -> WorkoutToken {
    let token = WorkoutToken()
    let send: (WorkoutToken, WorkoutEvent) -> Void = { [weak self] token, event in
      self?.onEvent?(token, event)
    }
    do {
      let live = try LiveWorkout(
        token: token, store: store, configuration: Self.configuration, send: send)
      current = live
      live.start(at: date)
    } catch {
      current = nil
      // After `start` returns, so the session knows the token (research R3).
      Task { send(token, .failed) }
    }
    return token
  }

  func pause() { current?.session.pause() }

  func resume() { current?.session.resume() }

  func statistics() -> WorkoutStatistics {
    guard let builder = current?.builder else { return WorkoutStatistics() }
    return Self.statistics { builder.statistics(for: $0) }
  }

  func save(endingAt date: Date) async throws -> SavedWorkout {
    guard let live = current else { throw NotAvailable() }
    // The save owns it from here: nothing else reads the ended workout (#30 R1-2).
    current = nil
    return try await live.save(endingAt: date)
  }

  func discard() {
    current?.discard()
    current = nil
  }

  /// FR-009a, Q6: the workout left running when the app was ended is finished now and saved
  /// as it is; a failure is ignored (research R10).
  func recoverAndSave() async {
    guard let session = try? await store.recoverActiveWorkoutSession() else { return }
    let builder = session.associatedWorkoutBuilder()
    let end = Date()
    session.end()
    do {
      try await builder.endCollection(at: end)
      _ = try await builder.finishWorkout()
    } catch {
      return
    }
  }

  /// Average and maximum heart rate (rounded beats per minute) and active energy
  /// (kilocalories), from the builder or the saved workout (research R7).
  nonisolated static func statistics(_ lookup: (HKQuantityType) -> HKStatistics?) -> WorkoutStatistics {
    let heartRate = lookup(HKQuantityType(.heartRate))
    return statistics(
      averageHeartRate: heartRate?.averageQuantity(),
      maximumHeartRate: heartRate?.maximumQuantity(),
      activeEnergy: lookup(HKQuantityType(.activeEnergyBurned))?.sumQuantity())
  }

  nonisolated static func statistics(
    averageHeartRate: HKQuantity?, maximumHeartRate: HKQuantity?, activeEnergy: HKQuantity?
  ) -> WorkoutStatistics {
    let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
    return WorkoutStatistics(
      averageHeartRate: averageHeartRate.map { Int($0.doubleValue(for: beatsPerMinute).rounded()) },
      maximumHeartRate: maximumHeartRate.map { Int($0.doubleValue(for: beatsPerMinute).rounded()) },
      activeEnergy: activeEnergy?.doubleValue(for: .kilocalorie()))
  }
}

/// One match's session and builder. Its callbacks carry its token, so a late event of an
/// earlier workout is dropped by the session (research R11, #28 R5-3).
private final class LiveWorkout: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
  let token: WorkoutToken
  let session: HKWorkoutSession
  let builder: HKLiveWorkoutBuilder
  private let send: (WorkoutToken, WorkoutEvent) -> Void
  /// The app asked for the end (save or discard): an `.ended` is expected, not reported.
  private var isEnding = false
  /// The session reached `.running` once: a failure before that is a failed start.
  private var didRun = false
  /// A failure or an unexpected end is reported once.
  private var didReport = false
  private var stopped: CheckedContinuation<Void, Never>?

  init(
    token: WorkoutToken, store: HKHealthStore, configuration: HKWorkoutConfiguration,
    send: @escaping (WorkoutToken, WorkoutEvent) -> Void
  ) throws {
    self.token = token
    self.send = send
    session = try HKWorkoutSession(healthStore: store, configuration: configuration)
    builder = session.associatedWorkoutBuilder()
    builder.dataSource = HKLiveWorkoutDataSource(
      healthStore: store, workoutConfiguration: configuration)
    super.init()
    session.delegate = self
    builder.delegate = self
  }

  func start(at date: Date) {
    session.startActivity(with: date)
    Task {
      do {
        try await builder.beginCollection(at: date)
      } catch {
        reportEnd()  // FR-010, Story 2 s9
      }
    }
  }

  /// Ends at the summary opening, or at HealthKit's last event if later (research R2, #28
  /// R5-2). A session the system already ended skips the calls that no longer apply, so what
  /// it collected is still saved if HealthKit allows it (#28 R6-4).
  func save(endingAt date: Date) async throws -> SavedWorkout {
    isEnding = true
    let end = WorkoutEndDate.effective(
      requested: date, eventDates: builder.workoutEvents.map(\.dateInterval.end))
    if session.state == .running || session.state == .paused {
      await stop(at: end)
    }
    if session.state != .ended { session.end() }
    try await builder.endCollection(at: end)
    guard let workout = try await builder.finishWorkout() else {
      throw HealthKitWorkoutService.NotAvailable()
    }
    return SavedWorkout(
      uuid: workout.uuid,
      statistics: HealthKitWorkoutService.statistics { workout.statistics(for: $0) })
  }

  /// FR-008, and a workout that failed (#30 R1-1).
  func discard() {
    isEnding = true
    resumeStopped()
    if session.state != .ended { session.end() }
    builder.discardWorkout()
  }

  /// `stopActivity(with:)`, then waits for `.stopped` (at most 3 s) before `end()`.
  private func stop(at date: Date) async {
    await withCheckedContinuation { continuation in
      stopped = continuation
      session.stopActivity(with: date)
      Task {
        try? await Task.sleep(for: .seconds(3))
        resumeStopped()
      }
    }
  }

  private func resumeStopped() {
    stopped?.resume()
    stopped = nil
  }

  private func changed(to state: HKWorkoutSessionState) {
    switch state {
    case .running: didRun = true
    case .stopped: resumeStopped()
    case .ended:
      resumeStopped()
      reportEnd()  // Story 2 s10
    default: break
    }
  }

  private func failed() {
    resumeStopped()
    reportEnd()
  }

  private func reportEnd() {
    guard !isEnding, !didReport else { return }
    didReport = true
    send(token, didRun ? .endedUnexpectedly : .failed)
  }

  // MARK: HKWorkoutSessionDelegate (nonisolated; hop to the main actor, research R11)

  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState, date: Date
  ) {
    Task { @MainActor in self.changed(to: toState) }
  }

  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession, didFailWithError error: any Error
  ) {
    Task { @MainActor in self.failed() }
  }

  // MARK: HKLiveWorkoutBuilderDelegate

  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    // Heart-rate readings for the header: 003 PR 3 (research R6).
  }

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
