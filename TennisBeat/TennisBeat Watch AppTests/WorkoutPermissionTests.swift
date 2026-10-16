import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// Playing without Health permission (spec 003 Story 5; T026).
@MainActor
struct WorkoutPermissionTests {
  @Test("US5 s1 without permission no workout call is made and the summary keeps Undo")
  func denied() async {
    let h = WorkoutHarness(.denied)
    h.start()
    h.tap("MOM")
    h.session.pause()
    h.session.resume()
    h.win()
    #expect(h.session.workoutState == .none)
    #expect(h.session.route == .summary)
    #expect(h.session.canUndo)
    h.session.undo()  // as in spec 002 FR-020
    #expect(h.session.route == .playing)
    h.tap("M")
    h.session.done()
    await settle()
    #expect(h.fake.calls.isEmpty)
    #expect(h.sleeper.waiting == 0)
  }

  @Test("US5 s2 workouts allowed but no reading: the workout runs and is saved")
  func grantedWithoutReadings() async {
    let h = WorkoutHarness(.granted)
    h.start()
    h.win()
    h.session.done()
    await settle()
    #expect(h.kinds == [.start, .pause, .save])
    #expect(h.session.workoutState == .saved)
  }

  @Test("US5 s4 a permission change applies from the next match")
  func permissionChangeBetweenMatches() async {
    let h = WorkoutHarness(.denied)
    h.start()
    h.win()
    h.fake.mode = .granted  // allowed in Settings during the match
    h.session.done()
    await settle()
    #expect(h.fake.calls.isEmpty)
    h.start()
    #expect(h.kinds == [.start])
    #expect(h.session.workoutState == .running)
  }

  @Test("US5 s4 a running match keeps its workout state when permission changes")
  func permissionChangeMidMatch() async {
    let h = WorkoutHarness(.granted)
    h.start()
    h.fake.mode = .denied  // revoked in Settings during the match
    h.session.pause()
    h.session.resume()
    h.win()
    h.session.done()
    await settle()
    #expect(h.kinds == [.start, .pause, .resume, .pause, .save])
  }
}
