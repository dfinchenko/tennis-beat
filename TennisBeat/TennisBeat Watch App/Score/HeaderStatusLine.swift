import SwiftUI

/// The line under the elapsed time (Watch 3): the heart rate, then the status, e.g.
/// "♥ 142 · Deuce" ([#31 L1](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6223261542),
/// Q3). When both don't fit, the status moves to its own line below; the heart rate never
/// sits beside the elapsed time, under the system clock. VoiceOver reads the heart rate with
/// the elapsed time and the status inside the score summary, so this line is hidden from it.
struct HeaderStatusLine: View {
  let clock: MatchClock
  let status: String
  /// The heart rate at a given time (Story 3).
  let heartRate: (Date) -> HeartRateDisplay
  var isDimmed = false
  /// `-uiTestExposeValues`: the heart rate and the status become elements UI tests can read.
  var exposeValues = false
  @Environment(\.locale) private var locale

  var body: some View {
    if isDimmed {
      // Always On: no heart rate (Story 3 s5), so no per-second redraw.
      statusText
    } else {
      // Redrawn every second with the elapsed time, so "--" follows a stale reading (R6).
      TimelineView(.periodic(from: clock.startedAt, by: 1)) { context in
        content(heartRate(context.date))
      }
    }
  }

  @ViewBuilder
  private func content(_ display: HeartRateDisplay) -> some View {
    if let text = display.text {
      let heart = HeartRateView(
        text: text, label: display.accessibilityLabel(locale: locale) ?? "",
        exposeValues: exposeValues
      )
      .transaction { $0.animation = display.animation }  // Story 3 s2
      if status.isEmpty {
        heart
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            heart
            Text(verbatim: "·")
              .font(.watchFootnote)
              .foregroundStyle(Color.watchTextSecondary)
              .accessibilityHidden(true)
            statusText
          }
          VStack(alignment: .leading, spacing: 0) {
            heart
            statusText
          }
        }
      }
    } else {
      statusText
    }
  }

  private var statusText: some View {
    Text(status)
      .font(.watchFootnote)
      .foregroundStyle(Color.watchTextSecondary)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .modifier(ExposedStatus(isOn: exposeValues))
  }
}

/// The heart icon and the number or "--" (Watch 3, Q3): Watch/Footnote, `status/heart` icon,
/// `watch/text-secondary` number with monospaced digits.
private struct HeartRateView: View {
  let text: String
  let label: String
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
    .font(.watchFootnote)
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

/// The status is read inside the score summary (spec 002 Story 7 s2); with
/// `-uiTestExposeValues` UI tests can find it as `status`.
private struct ExposedStatus: ViewModifier {
  let isOn: Bool

  func body(content: Content) -> some View {
    if isOn {
      content.accessibilityIdentifier("status")
    } else {
      content.accessibilityHidden(true)
    }
  }
}
