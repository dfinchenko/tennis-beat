import SwiftUI
import TennisCore

/// Watch 3 — Score: the header (Undo, elapsed time, status), the VoiceOver summary and two
/// equal tap zones, Opponent on top (Story 2, FR-005..FR-009, FR-026).
struct ScoreView: View {
  @Environment(MatchSession.self) private var session
  @Environment(\.locale) private var locale
  private let exposeValues = LaunchOptions.current.exposeValues

  var body: some View {
    if let match = session.match, let clock = session.clock {
      let model = ScoreScreenModel(state: match.state, isPaused: session.isPaused, locale: locale)
      VStack(spacing: 4) {
        header(model, clock: clock)
        ForEach(model.zones, id: \.player) { zone in
          Button {
            session.addPoint(for: zone.player)
          } label: {
            // One element in production: the drawn values are hidden and the button reads
            // the zone sentence. UI tests see the values only with -uiTestExposeValues
            // (research R7). `.accessibilityElement(children: .ignore)` on the button keeps
            // the inner elements on watchOS, so the content is hidden instead.
            PlayerZoneView(zone: zone, exposeValues: exposeValues)
              .accessibilityHidden(!exposeValues)
          }
          .buttonStyle(.plain)
          .disabled(!session.acceptsPoints)
          .modifier(ExposeChildren(isOn: exposeValues))
          .accessibilityLabel(zone.accessibilityLabel)
          .accessibilityHint(zone.accessibilityHint)
          .accessibilityIdentifier("zone.\(zone.player.rawValue)")
        }
      }
      // The header shares the top row with the system clock, as in Watch 3, so the zones
      // keep at least 44 pt each on the 40 mm watch.
      .ignoresSafeArea(edges: .top)
      // Q9: the score screen stops at the largest standard size.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
  }

  private func header(_ model: ScoreScreenModel, clock: MatchClock) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Button(action: session.undo) {
        Image(systemName: "arrow.uturn.backward")
          .font(.watchTitle)
          .foregroundStyle(Color.watchTextPrimary)
          .frame(width: 44, height: 44)
          .background(Color.watchSurfaceRaised, in: .circle)
          .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .disabled(!session.canUndo)
      .opacity(session.canUndo ? 1 : 0.4)
      .accessibilityLabel(Text("score.undo"))
      .accessibilityIdentifier("undo")

      VStack(alignment: .leading, spacing: 0) {
        ElapsedTimeView(clock: clock)
          .accessibilitySortPriority(2)
        // The status line; VoiceOver reads it inside the summary instead (Story 7 s2).
        Text(model.statusText)
          .font(.watchFootnote)
          .foregroundStyle(Color.watchTextSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
          .accessibilityHidden(true)
      }
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
      .overlay {
        // The score summary, read right after the elapsed time (Story 7 s1). It covers the
        // whole column, so its frame meets the 44 pt audit minimum.
        Color.clear
          .accessibilityElement()
          .accessibilityLabel(model.summaryAccessibilityLabel)
          .accessibilityIdentifier("score.summary")
          .accessibilitySortPriority(1)
      }
      .accessibilityElement(children: .contain)
    }
  }
}

/// `-uiTestExposeValues`: the zone becomes a container, so UI tests can read its values.
private struct ExposeChildren: ViewModifier {
  let isOn: Bool

  func body(content: Content) -> some View {
    if isOn {
      content.accessibilityElement(children: .contain)
    } else {
      content
    }
  }
}

#Preview {
  let session = MatchSession.preview
  session.start(firstServer: .me)
  return ScoreView().environment(session)
}
