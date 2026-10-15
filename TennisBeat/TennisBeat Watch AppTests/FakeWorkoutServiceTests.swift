import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// The fake workout service that unit and UI tests use instead of HealthKit (T004).
@MainActor
struct FakeWorkoutServiceTests {
  private let clock = FakeClock()

  @Test("Contract §2: denied — the sheet was answered and workouts are not allowed")
  func denied() async {
    let fake = FakeWorkoutService(mode: .denied, now: clock.now)
    #expect(await fake.authorizationRequestStatus() == .unnecessary)
    #expect(!fake.canStartWorkout)
  }

  @Test("Contract §2: shouldRequest — Continue answers the sheet as granted")
  func shouldRequest() async {
    let fake = FakeWorkoutService(mode: .shouldRequest, now: clock.now)
    #expect(await fake.authorizationRequestStatus() == .shouldRequest)
    #expect(!fake.canStartWorkout)
    await fake.requestAuthorization()
    #expect(await fake.authorizationRequestStatus() == .unnecessary)
    #expect(fake.canStartWorkout)
    #expect(fake.calls == [.requestAuthorization])
  }

  @Test("Contract §2: granted — the sheet was answered and workouts are allowed")
  func granted() async {
    let fake = FakeWorkoutService(mode: .granted, now: clock.now)
    #expect(await fake.authorizationRequestStatus() == .unnecessary)
    #expect(fake.canStartWorkout)
  }

  @Test("Contract §2: failing — the workout reports .failed after start")
  func failing() {
    let fake = FakeWorkoutService(mode: .failing, now: clock.now)
    var events: [WorkoutEvent] = []
    fake.onEvent = { _, event in events.append(event) }
    _ = fake.start(at: clock.current)
    #expect(events == [.failed])
  }

  @Test("The fake records every workout call in order, with the time of each call")
  func recordsCalls() async throws {
    let fake = FakeWorkoutService(mode: .granted, now: clock.now)
    let start = clock.current
    let token = fake.start(at: start)
    clock.advance(by: 10)
    fake.pause()
    clock.advance(by: 5)
    fake.resume()
    let end = clock.current
    _ = try await fake.save(endingAt: end)
    #expect(
      fake.calls == [
        .start(at: start, token: token), .pause(at: start + 10), .resume(at: start + 15),
        .save(endingAt: end),
      ])
    // Positive control: a fresh fake has no calls.
    #expect(FakeWorkoutService(mode: .granted, now: clock.now).calls.isEmpty)
  }

  @Test("-uiTestSaveFails: save throws, and it is still recorded")
  func saveFails() async {
    let fake = FakeWorkoutService(mode: .granted, now: clock.now, saveFails: true)
    _ = fake.start(at: clock.current)
    await #expect(throws: (any Error).self) { try await fake.save(endingAt: clock.current) }
    #expect(fake.calls.last == .save(endingAt: clock.current))
  }

  @Test("Each start gets a new token")
  func tokens() {
    let fake = FakeWorkoutService(mode: .granted, now: clock.now)
    #expect(fake.start(at: clock.current) != fake.start(at: clock.current))
  }
}
