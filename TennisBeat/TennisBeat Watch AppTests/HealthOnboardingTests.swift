import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// User Story 1: when the Health onboarding shows, and what its buttons do
/// (data-model § HealthOnboarding, research R8, T011).
@MainActor
struct HealthOnboardingTests {
  private let clock = FakeClock()

  private func onboarding(_ mode: FakeHealthMode, sleep: ManualSleep = ManualSleep())
    -> (HealthOnboarding, FakeWorkoutService)
  {
    let fake = FakeWorkoutService(mode: mode, now: clock.now)
    return (HealthOnboarding(service: fake, sleep: sleep.sleep), fake)
  }

  @Test("US1 s1 the sheet was never answered: the onboarding shows")
  func showsWhenNeverAnswered() async {
    let (onboarding, _) = onboarding(.shouldRequest)
    await onboarding.load()
    #expect(onboarding.isReady)
    #expect(onboarding.needsOnboarding)
  }

  @Test("US1 s3 Continue asks once, then New match")
  func continueRequests() async {
    let (onboarding, fake) = onboarding(.shouldRequest)
    await onboarding.load()
    await onboarding.allow()
    #expect(fake.calls == [.requestAuthorization])
    #expect(!onboarding.needsOnboarding)
  }

  @Test("US1 s4 Not now: no sheet, New match; the next launch shows the onboarding again")
  func notNowSkipsThisLaunch() async {
    let (onboarding, fake) = onboarding(.shouldRequest)
    await onboarding.load()
    onboarding.notNow()
    #expect(!onboarding.needsOnboarding)
    #expect(fake.calls.isEmpty)

    // The next launch: a new onboarding over a sheet that is still unanswered (Q4).
    let next = HealthOnboarding(service: fake, sleep: ManualSleep().sleep)
    await next.load()
    #expect(next.needsOnboarding)
  }

  @Test(
    "US1 s5 once the sheet was answered the onboarding never shows",
    arguments: [FakeHealthMode.denied, .granted])
  func answeredNeverShows(mode: FakeHealthMode) async {
    let (onboarding, _) = onboarding(mode)
    await onboarding.load()
    #expect(onboarding.isReady)
    #expect(!onboarding.needsOnboarding)
  }

  @Test("US1 s5 an unknown status (a HealthKit error) never shows the onboarding")
  func unknownNeverShows() async {
    let (onboarding, fake) = onboarding(.shouldRequest)
    fake.statusOverride = .unknown
    await onboarding.load()
    #expect(onboarding.isReady)
    #expect(!onboarding.needsOnboarding)
  }

  @Test("US1 s1, s6 nothing shows while the status is read; a late answer is ignored")
  func waitsAtMostOneSecond() async {
    let sleep = ManualSleep()
    let gate = ManualSleep()
    let (onboarding, fake) = onboarding(.shouldRequest, sleep: sleep)
    fake.beforeStatus = { try? await gate.sleep(.zero) }

    let load = Task { await onboarding.load() }
    await sleep.untilWaiting()
    await gate.untilWaiting()
    #expect(!onboarding.isReady)  // neither New match nor the onboarding yet
    #expect(!onboarding.needsOnboarding)

    sleep.release()  // 1 s passes without an answer: New match
    await settle()
    #expect(onboarding.isReady)
    #expect(!onboarding.needsOnboarding)

    gate.release()  // the late .shouldRequest is ignored for this launch
    await load.value
    #expect(!onboarding.needsOnboarding)
  }

  @Test("US1 s1 an answer within 1 s shows the onboarding, never New match first")
  func answerWithinTimeout() async {
    let sleep = ManualSleep()
    let (onboarding, _) = onboarding(.shouldRequest, sleep: sleep)
    #expect(!onboarding.isReady)
    await onboarding.load()
    #expect(onboarding.isReady)
    #expect(onboarding.needsOnboarding)
    sleep.release()  // the timeout firing later changes nothing
    await settle()
    #expect(onboarding.needsOnboarding)
  }
}
