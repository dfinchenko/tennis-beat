import Foundation
import Observation

/// Whether the Health onboarding shows before New match (data-model § HealthOnboarding,
/// Story 1, Q4). It stores nothing: "the sheet was answered" is HealthKit's own state, and
/// Not now lasts for this launch only.
@Observable
final class HealthOnboarding {
  /// HealthKit's answer, once read; `nil` until then or when it came too late.
  private(set) var requestStatus: AuthorizationRequestStatus?
  /// Not now (Q4); not stored, so the onboarding returns on the next launch.
  private(set) var skippedThisLaunch = false
  /// The status was read, or 1 s passed without an answer. Until then the root view shows
  /// nothing, so New match never flashes before the onboarding (Story 1 s1).
  private(set) var isReady = false

  var needsOnboarding: Bool {
    isReady && requestStatus == .shouldRequest && !skippedThisLaunch
  }

  @ObservationIgnored private let service: WorkoutService
  @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

  init(
    service: WorkoutService,
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) {
    self.service = service
    self.sleep = sleep
  }

  /// Reads the status once at launch, waiting at most 1 s, so a slow read never blocks
  /// New match (Story 1 s6). An answer after the timeout is ignored for this launch.
  func load() async {
    let timeout = Task { [sleep] in
      do {
        try await sleep(.seconds(1))
      } catch {
        return  // cancelled: the answer came first
      }
      self.isReady = true
    }
    let status = await service.authorizationRequestStatus()
    timeout.cancel()
    guard !isReady else { return }
    requestStatus = status
    isReady = true
  }

  /// Continue: the system sheet; whatever the answer, New match next (Story 1 s3).
  func allow() async {
    await service.requestAuthorization()
    requestStatus = .unnecessary
  }

  /// Not now: New match, no sheet (Story 1 s4).
  func notNow() {
    skippedThisLaunch = true
  }
}

#if DEBUG
  extension HealthOnboarding {
    /// An onboarding for SwiftUI previews that shows the screen.
    static var preview: HealthOnboarding {
      HealthOnboarding(service: FakeWorkoutService(mode: .shouldRequest, now: Date.init))
    }
  }
#endif
