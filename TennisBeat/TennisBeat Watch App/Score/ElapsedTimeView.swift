import SwiftUI

/// Elapsed match time, redrawn every second: minutes and seconds, or hours from one hour on,
/// with monospaced digits (FR-009, FR-022, research R5).
struct ElapsedTimeView: View {
  let clock: MatchClock
  var identifier = "elapsed"
  /// Always On (Watch 5), passed by the score view. Read here from the environment, it
  /// stayed false under `-uiTestAlwaysOn` in the simulator while the score view's was true.
  var isDimmed = false
  @Environment(\.locale) private var locale

  var body: some View {
    if isDimmed {
      // Always On: whole minutes, redrawn as each elapsed minute is reached (Story 6 s1).
      TimelineView(ElapsedMinuteSchedule(clock: clock)) { context in
        Text(ScoreScreenModel.dimmedElapsed(clock.elapsed(at: context.date), locale: locale))
          .font(.watchTitle)
          .foregroundStyle(Color.watchTextSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .accessibilityIdentifier(identifier)
      }
    } else {
      TimelineView(.periodic(from: clock.startedAt, by: 1)) { context in
        Text(Self.format(clock.elapsed(at: context.date)))
          .font(.watchTitle)
          .monospacedDigit()
          .foregroundStyle(Color.brandBall)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .accessibilityIdentifier(identifier)
      }
    }
  }

  static func format(_ seconds: TimeInterval) -> String {
    let duration = Duration.seconds(Int(seconds))
    return duration.formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
  }
}
