import SwiftUI

/// Elapsed match time, redrawn every second: minutes and seconds, or hours from one hour on,
/// with monospaced digits (FR-009, FR-022, research R5). Spec 003: the heart rate follows the
/// time on the same line, redrawn with it (Story 3, research R6).
struct ElapsedTimeView: View {
  let clock: MatchClock
  var identifier = "elapsed"
  /// The heart rate at a given time; no row by default (spec 002 screens).
  var heartRate: (Date) -> HeartRateDisplay = { _ in .hidden }
  /// `-uiTestExposeValues`: the heart rate becomes an element UI tests can read.
  var exposeValues = false
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
        let display = heartRate(context.date)
        // Q3: "42:18 ♥ 142" on one line; if that doesn't fit, the heart rate gets smaller.
        ViewThatFits(in: .horizontal) {
          line(context.date, display, heartFont: .watchFootnote)
          line(context.date, display, heartFont: .watchCaption)
        }
      }
    }
  }

  private func line(_ date: Date, _ display: HeartRateDisplay, heartFont: Font) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(Self.format(clock.elapsed(at: date)))
        .font(.watchTitle)
        .monospacedDigit()
        .foregroundStyle(Self.color(isDimmed: false))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        // VoiceOver reads the heart rate with the time, not as its own stop (Story 3 s6).
        .accessibilityValue(Text(display.accessibilityLabel(locale: locale) ?? ""))
        .accessibilityIdentifier(identifier)
      if let text = display.text {
        HeartRateView(
          text: text, label: display.accessibilityLabel(locale: locale) ?? "", font: heartFont,
          exposeValues: exposeValues
        )
        .transaction { $0.animation = display.animation }  // Story 3 s2
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

/// The heart icon and the number or "--" (Watch 3, Q3): Watch/Footnote, `status/heart` icon,
/// `watch/text-secondary` number with monospaced digits.
private struct HeartRateView: View {
  let text: String
  let label: String
  let font: Font
  let exposeValues: Bool

  var body: some View {
    let row = HStack(spacing: 2) {
      Image(systemName: "heart.fill")
        .foregroundStyle(Color.statusHeart)
        .accessibilityHidden(true)
      Text(text)
        .monospacedDigit()
        .foregroundStyle(Color.watchTextSecondary)
        .accessibilityIdentifier("heartRate.value")
    }
    .font(font)
    .lineLimit(1)
    .fixedSize()
    if exposeValues {
      row
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("heartRate")
    } else {
      row.accessibilityHidden(true)  // read with the elapsed time
    }
  }
}
