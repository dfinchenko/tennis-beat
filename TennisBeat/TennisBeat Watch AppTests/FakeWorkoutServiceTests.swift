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
  func failing() async {
    let fake = FakeWorkoutService(mode: .failing, now: clock.now)
    var events: [WorkoutEvent] = []
    fake.onEvent = { _, event in events.append(event) }
    _ = fake.start(at: clock.current)
    // Reported after `start` returns, as HealthKit does, so the session knows the token.
    await settle()
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

  @Test("Contract §2: -uiTestHeartRate — one reading at the start, for that workout")
  func heartRateAtStart() async {
    let fake = FakeWorkoutService(mode: .granted, now: clock.now, heartRate: 142)
    var events: [(WorkoutToken, WorkoutEvent)] = []
    fake.onEvent = { events.append(($0, $1)) }
    let token = fake.start(at: clock.current)
    await settle()
    #expect(events.count == 1)
    #expect(events.first?.0 == token)
    #expect(events.first?.1 == .heartRate(HeartRateReading(bpm: 142, date: clock.current)))
    // Positive control: without the argument there is no reading.
    let silent = FakeWorkoutService(mode: .granted, now: clock.now)
    var none: [WorkoutEvent] = []
    silent.onEvent = { none.append($1) }
    _ = silent.start(at: clock.current)
    await settle()
    #expect(none.isEmpty)
  }

  @Test("Each start gets a new token")
  func tokens() {
    let fake = FakeWorkoutService(mode: .granted, now: clock.now)
    #expect(fake.start(at: clock.current) != fake.start(at: clock.current))
  }

  @Test("Contract §2: the launch arguments build the fake; without -uiTestHealth, none")
  func launched() throws {
    #expect(FakeWorkoutService.launched(LaunchOptions(arguments: []), now: clock.now) == nil)
    let fake = try #require(
      FakeWorkoutService.launched(
        LaunchOptions(arguments: [
          "-uiTestHealth", "granted", "-uiTestHeartRate", "142", "-uiTestWorkoutStats",
          "138,171,612",
        ]), now: clock.now))
    #expect(fake.mode == .granted)
    #expect(fake.heartRate == 142)
    #expect(
      fake.stats
        == WorkoutStatistics(averageHeartRate: 138, maximumHeartRate: 171, activeEnergy: 612))
    #expect(!fake.saveFails)
  }

  @Test(
    "Contract §2: -uiTestSaveFails at launch: the first save fails 2 s after it starts; the next one works"
  )
  func launchedSaveFails() async throws {
    let sleeper = ManualSleep()
    let fake = try #require(
      FakeWorkoutService.launched(
        LaunchOptions(arguments: ["-uiTestHealth", "granted", "-uiTestSaveFails"]),
        now: clock.now, sleep: sleeper.sleep))
    _ = fake.start(at: clock.current)
    let first = Task { try await fake.save(endingAt: clock.current) }
    await sleeper.untilWaiting()
    #expect(sleeper.requested == [.seconds(2)])  // a New match shows before the failure
    sleeper.release()
    await #expect(throws: (any Error).self) { try await first.value }
    _ = fake.start(at: clock.current)
    let second = try await fake.save(endingAt: clock.current)
    #expect(second.statistics == fake.stats)
    #expect(sleeper.requested == [.seconds(2)])  // the working save doesn't wait
  }

  @Test("FR-013 the saved workout's statistics can differ from the live ones (savedStats)")
  func savedStats() async throws {
    let fake = FakeWorkoutService(mode: .granted, now: clock.now)
    fake.stats = WorkoutStatistics(averageHeartRate: 138, maximumHeartRate: 171, activeEnergy: 612)
    _ = fake.start(at: clock.current)
    #expect(try await fake.save(endingAt: clock.current).statistics == fake.stats)
    let saved = WorkoutStatistics(averageHeartRate: 139, maximumHeartRate: 171, activeEnergy: 615)
    fake.savedStats = saved
    _ = fake.start(at: clock.current)
    #expect(try await fake.save(endingAt: clock.current).statistics == saved)
  }
}
