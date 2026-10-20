import SwiftUI
import TennisCore

/// Watch 3 — Score: the header (Undo, elapsed time, status), the VoiceOver summary and two
/// equal tap zones, Opponent on top (Story 2, FR-005..FR-009, FR-026). In Always On it is
/// Watch 5: dimmed, minutes only, no Undo, and the zones take no taps (Story 6, FR-021).
struct ScoreView: View {
  @Environment(MatchSession.self) private var session
  @Environment(\.locale) private var locale
  @Environment(\.isLuminanceReduced) private var isLuminanceReduced
  private let exposeValues = LaunchOptions.current.exposeValues

  var body: some View {
    if let match = session.match, let clock = session.clock {
      let model = ScoreScreenModel(
        state: match.state, isPaused: session.isPaused, locale: locale,
        acceptsPoints: session.acceptsPoints, isDimmed: isLuminanceReduced,
        gameScoring: match.setup.format.gameScoring)
      VStack(spacing: 4) {
        header(model, clock: clock)
        ForEach(model.zones, id: \.player) { zone in
          Button {
            #if DEBUG
              TapLog.log(
                "zone \(zone.player.rawValue) action ran: events \(session.match?.events.count ?? -1) accepts \(session.acceptsPoints) dimmed \(isLuminanceReduced) zonesAcceptTaps \(model.zonesAcceptTaps(isLuminanceReduced: isLuminanceReduced))"
              )
            #endif
            session.addPoint(for: zone.player)
          } label: {
            // One element in production: the drawn values are hidden and the button reads
            // the zone sentence. UI tests see the values only with -uiTestExposeValues
            // (research R7). `.accessibilityElement(children: .ignore)` on the button keeps
            // the inner elements on watchOS, so the content is hidden instead.
            PlayerZoneView(zone: zone, isDimmed: isLuminanceReduced, exposeValues: exposeValues)
              .accessibilityHidden(!exposeValues)
          }
          .buttonStyle(.plain)
          // Always On: a lowered wrist must not score, by touch or by a VoiceOver activation
          // (Story 6 s3, #24 R1-4).
          .disabled(!model.zonesAcceptTaps(isLuminanceReduced: isLuminanceReduced))
          .allowsHitTesting(model.zonesAcceptTaps(isLuminanceReduced: isLuminanceReduced))
          // Q4: the zones dim while paused; "Paused" in the status line says why.
          .opacity(session.isPaused ? 0.5 : 1)
          .modifier(ExposeChildren(isOn: exposeValues))
          .accessibilityLabel(zone.accessibilityLabel)
          .accessibilityHint(zone.accessibilityHint)
          .accessibilityIdentifier("zone.\(zone.player.rawValue)")
          .touchLog("zone \(zone.player.rawValue)")
        }
      }
      .touchLog("score screen")
      // The header shares the top row with the system clock, as in Watch 3, so the zones
      // keep at least 44 pt each on the 40 mm watch.
      .ignoresSafeArea(edges: .top)
      // Q9: the score screen stops at the largest standard size.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      // No animations in Always On (Story 6 s2).
      .transaction { if isLuminanceReduced { $0.animation = nil } }
      #if DEBUG
        .onAppear { TapLog.log("score view appeared, dimmed \(isLuminanceReduced)") }
        .onDisappear { TapLog.log("score view disappeared") }
        .onChange(of: isLuminanceReduced) { _, dimmed in TapLog.log("dimmed -> \(dimmed)") }
        // What else can make the zones ignore a tap that reaches them (#33 R1-1).
        .onChange(of: model.zonesAcceptTaps(isLuminanceReduced: isLuminanceReduced)) { _, on in
          TapLog.log("zonesAcceptTaps -> \(on)")
        }
        .onChange(of: session.acceptsPoints) { _, on in TapLog.log("acceptsPoints -> \(on)") }
        .onChange(of: session.isPaused) { _, paused in TapLog.log("paused -> \(paused)") }
        .onChange(of: session.route) { _, route in TapLog.log("route -> \(route)") }
      #endif
    }
  }

  private func header(_ model: ScoreScreenModel, clock: MatchClock) -> some View {
    HStack(alignment: .top, spacing: 8) {
      if model.showsUndo { undoButton }

      VStack(alignment: .leading, spacing: 0) {
        ElapsedTimeView(clock: clock, heartRate: heartRate(at:), isDimmed: isLuminanceReduced)
          .accessibilitySortPriority(2)
        // The heart rate, then the status (#31 L1); VoiceOver reads the heart rate with the
        // elapsed time and the status inside the summary (Story 7 s2).
        HeaderStatusLine(
          clock: clock, status: model.statusText, layoutStatus: model.layoutStatusText,
          heartRate: heartRate(at:),
          isDimmed: isLuminanceReduced, exposeValues: exposeValues
        )
        .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
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

  /// The header's heart rate at `date` (Story 3, FR-012).
  private func heartRate(at date: Date) -> HeartRateDisplay {
    HeartRateDisplay(
      workoutState: session.workoutState, reading: session.latestHeartRate, now: date,
      isDimmed: isLuminanceReduced)
  }

  private var undoButton: some View {
    Button {
      #if DEBUG
        TapLog.log(
          "undo action ran: events \(session.match?.events.count ?? -1) canUndo \(session.canUndo) dimmed \(isLuminanceReduced)"
        )
      #endif
      session.undo()
    } label: {
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
  }
}

extension View {
  /// DEBUG only: logs each tap that reaches this view and where, so a lost tap shows whether
  /// it reached the zone without its action running, or never reached the app (Denys, after
  /// #35). Release builds return the view unchanged.
  func touchLog(_ name: String) -> some View {
    #if DEBUG
      modifier(TouchLogging(name: name))
    #else
      self
    #endif
  }
}

#if DEBUG
  /// A simultaneous spatial tap: it logs every tap that reaches the view and takes nothing from
  /// the button. It drops out as soon as the finger moves, so the page swipe to Controls is
  /// untouched; a drag or a never-ending long press here took that swipe.
  private struct TouchLogging: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
      content.simultaneousGesture(
        SpatialTapGesture(coordinateSpace: .global).onEnded { value in
          TapLog.log("tap reached \(name) at \(Self.point(value.location))")
        })
    }

    private static func point(_ point: CGPoint) -> String {
      "\(Int(point.x.rounded())),\(Int(point.y.rounded()))"
    }
  }
#endif

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

#if DEBUG
  #Preview {
    let session = MatchSession.preview
    session.start(firstServer: .me)
    return ScoreView().environment(session)
  }

  #Preview("Always On") {
    let session = MatchSession.preview
    session.start(firstServer: .me)
    session.addPoint(for: .me)
    return ScoreView().environment(session).environment(\.isLuminanceReduced, true)
  }
#endif
