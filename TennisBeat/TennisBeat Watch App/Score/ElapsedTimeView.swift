import SwiftUI

/// Elapsed match time, redrawn every second: minutes and seconds, or hours from one hour on,
/// with monospaced digits (FR-009, FR-022, research R5). Spec 003: its VoiceOver value is the
/// heart rate (Story 3 s6, research R6).
struct ElapsedTimeView: View {
  let clock: MatchClock
  var identifier = "elapsed"
  /// The heart rate at a given time, read by VoiceOver; none by default (spec 002 screens).
  var heartRate: (Date) -> HeartRateDisplay = { _ in .hidden }
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
          .foregroundStyle(Self.color(isDimmed: true))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .accessibilityIdentifier(identifier)
      }
    } else {
      TimelineView(.periodic(from: clock.startedAt, by: 1)) { context in
        Text(Self.format(clock.elapsed(at: context.date)))
          .font(.watchTitle)
          .monospacedDigit()
          .foregroundStyle(Self.color(isDimmed: false))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          // VoiceOver reads the heart rate with the time, not as its own stop (Story 3 s6);
          // it is drawn on the line below (HeaderStatusLine, #31 L1).
          .accessibilityValue(
            Text(heartRate(context.date).accessibilityLabel(locale: locale) ?? "")
          )
          .accessibilityIdentifier(identifier)
      }
    }
  }

  /// The header colour: the ball colour, or `text-tertiary` grey in Always On (Watch 5,
  /// Story 6 s1).
  static func color(isDimmed: Bool) -> Color {
    isDimmed ? .watchTextTertiary : .brandBall
  }

  static func format(_ seconds: TimeInterval) -> String {
    let duration = Duration.seconds(Int(seconds))
    return duration.formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
  }
}
