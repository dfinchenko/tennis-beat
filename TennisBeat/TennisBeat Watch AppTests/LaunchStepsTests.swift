import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// `-uiTestPoints` with Undo and server corrections (spec 002 contract §2): the SC-002 UI tests
/// play the long part of each scripted sequence at launch and only the last steps with real
/// taps (Denys, relayed on #36:
/// https://github.com/dfinchenko/tennis-beat/pull/36#issuecomment-6301821874). The launch
/// must give the same events as the taps would.
@MainActor
struct LaunchStepsTests {
  private let clock = FakeClock()

  @Test(
    "-uiTestPoints reads M, O, U (Undo) and S (server correction); other characters are ignored")
  func parses() {
    let options = LaunchOptions(arguments: ["-uiTestPoints", "MOU-S M"])
    #expect(options.points == [.point(.me), .point(.opponent), .undo, .correctServer, .point(.me)])
    #expect(LaunchOptions(arguments: []).points.isEmpty)
  }

  @Test("SC-002 the launch steps give the same events as the engine given the same commands")  // ITF: CE-02
  func playMatchesTheEngine() throws {
    let session = MatchSession(
      store: FormatStore(defaults: UserDefaults(suiteName: "LaunchStepsTests.\(UUID())")!),
      haptics: RecordingHaptics(), announcer: RecordingAnnouncer(),
      workout: FakeWorkoutService.denied(), now: clock.now)
    session.formatChoice.setLength = .four
    session.start(firstServer: .me)
    let steps = LaunchOptions(arguments: ["-uiTestPoints", "MMMMOUSOOOOM"]).points
    for step in steps { session.play(step) }

    let format = try #require(session.formatChoice.matchFormat)
    var expected = Match(setup: MatchSetup(format: format, firstServer: .me))
    for character in "MMMMO" {
      try expected.recordPoint(wonBy: character == "M" ? .me : .opponent, at: clock.now())
    }
    expected.undo()
    try expected.correctFirstServer(to: .opponent)
    for character in "OOOOM" {
      try expected.recordPoint(wonBy: character == "M" ? .me : .opponent, at: clock.now())
    }
    let match = try #require(session.match)
    #expect(match.events.map(Self.kind) == expected.events.map(Self.kind))
    #expect(match.state == expected.state)
  }

  /// An event without its time, which the session takes from its own clock.
  private static func kind(_ event: MatchEvent) -> String {
    switch event {
    case .point(let player, _): "point \(player)"
    default: "\(event)"
    }
  }
}
