import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// FR-009a: a workout left running when the app was ended is saved as it is (Q6, research
/// R10; T027).
@MainActor
struct WorkoutRecoveryTests {
  @Test("FR-009a recovery saves the running workout once and leaves New match")
  func recoverSaves() async {
    let h = WorkoutHarness()
    await WorkoutRecovery(service: h.fake).recover()
    #expect(h.fake.calls == [.recoverAndSave])
    #expect(h.session.route == .setup)
    #expect(h.session.match == nil)
    #expect(h.session.workoutState == .none)
  }

  @Test("FR-009a a failing recovery is ignored")
  func failingRecoveryIgnored() async {
    let h = WorkoutHarness(saveFails: true)
    await WorkoutRecovery(service: h.fake).recover()
    #expect(h.fake.calls == [.recoverAndSave])
    #expect(h.session.route == .setup)
    #expect(!h.session.pendingSaveFailureNotice)
  }
}
