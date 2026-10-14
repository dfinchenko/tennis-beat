import SwiftUI
import TennisCore

/// Watch 4 — Controls: the elapsed time and four round buttons with labels: Undo,
/// Pause / Resume, Server and End (Story 4, FR-014..FR-018). It scrolls, so large text
/// never clips.
struct ControlsView: View {
  @Environment(MatchSession.self) private var session
  @State private var isConfirmingEnd = false
  @Environment(\.isLuminanceReduced) private var isLuminanceReduced
  private let exposeValues = LaunchOptions.current.exposeValues
  /// Text heights at the current size, for the round-button size below.
  @ScaledMetric(relativeTo: .body) private var elapsedHeight: CGFloat = 21
  @ScaledMetric(relativeTo: .subheadline) private var labelHeight: CGFloat = 18

  /// The layout values that `content` uses and `diameter(for:)` adds up (#23 R1-5).
  private enum Metrics {
    static let topPadding: CGFloat = 4
    /// Between the elapsed time and the grid, and between the grid's rows.
    static let rowSpacing: CGFloat = 4
    static let columnSpacing: CGFloat = 8
    static let circleToLabel: CGFloat = 2
    static let oneColumnSpacing: CGFloat = 8
    /// The page dots under the content.
    static let pageIndicator: CGFloat = 14
    /// The 40 mm watch is 162 × 197 pt; wider watches keep the designed size.
    static let smallWatchWidth: CGFloat = 162
    static let designDiameter: CGFloat = 64
    static let minimumDiameter: CGFloat = 48
  }

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        content(diameter: diameter(for: proxy.size))
          .padding(.top, Metrics.topPadding)
      }
    }
    // The elapsed time shares the top row with the system clock, as on Score, so the
    // controls get the height.
    .ignoresSafeArea(edges: .top)
    .confirmationDialog(
      Text("confirm.end.title"), isPresented: $isConfirmingEnd, titleVisibility: .visible
    ) {
      Button(role: .destructive, action: session.endEarly) {
        Text("confirm.end.action")
      }
      // Contract §1; watchOS gives dialog actions no identifier, so UI tests find this
      // button by its label (#21 R1-4).
      .accessibilityIdentifier("confirm.end")
    }
  }

  /// #21 decision: on the 40 mm watch the largest round button at which all four controls
  /// fit without scrolling at the default text size, never below 48 pt; 64 pt (Watch 4) on
  /// larger watches. At larger text sizes the page scrolls.
  private func diameter(for size: CGSize) -> CGFloat {
    guard size.width <= Metrics.smallWatchWidth else { return Metrics.designDiameter }
    // Top padding, elapsed-to-grid and row gaps, and circle-to-label in both rows.
    let spacing = Metrics.topPadding + 2 * Metrics.rowSpacing + 2 * Metrics.circleToLabel
    let fit =
      (size.height - Metrics.pageIndicator - elapsedHeight - 2 * labelHeight - spacing) / 2
    return min(Metrics.designDiameter, max(Metrics.minimumDiameter, fit.rounded(.down)))
  }

  private func content(diameter: CGFloat) -> some View {
    VStack(spacing: Metrics.rowSpacing) {
      if let clock = session.clock {
        // Whole minutes if the wrist drops on this page (#24 R1-2).
        ElapsedTimeView(clock: clock, identifier: "controls.elapsed", isDimmed: isLuminanceReduced)
      }
      // A 2×2 grid while every label fits on one line; one column otherwise, so long
      // labels (UK «Продовжити» at large sizes) wrap between words, never inside one.
      ViewThatFits(in: .horizontal) {
        Grid(horizontalSpacing: Metrics.columnSpacing, verticalSpacing: Metrics.rowSpacing) {
          GridRow {
            undo(singleLine: true, diameter: diameter)
            pauseResume(singleLine: true, diameter: diameter)
          }
          GridRow {
            server(singleLine: true, diameter: diameter)
            end(singleLine: true, diameter: diameter)
          }
        }
        VStack(spacing: Metrics.oneColumnSpacing) {
          undo(singleLine: false, diameter: diameter)
          pauseResume(singleLine: false, diameter: diameter)
          server(singleLine: false, diameter: diameter)
          end(singleLine: false, diameter: diameter)
        }
      }
    }
  }

  private func undo(singleLine: Bool, diameter: CGFloat) -> some View {
    control(
      "score.undo", systemImage: "arrow.uturn.backward", fill: .watchSurfaceRaised,
      glyph: .watchTextPrimary, id: "controls.undo", singleLine: singleLine, diameter: diameter,
      action: session.undo
    )
    .disabled(!session.canUndo)
  }

  private func pauseResume(singleLine: Bool, diameter: CGFloat) -> some View {
    control(
      session.isPaused ? "controls.resume" : "controls.pause",
      systemImage: session.isPaused ? "play.fill" : "pause.fill", fill: .watchControlPause,
      glyph: .brandBall, id: "controls.pauseResume", singleLine: singleLine, diameter: diameter
    ) {
      session.isPaused ? session.resume() : session.pause()
    }
  }

  /// The first-server correction (ITF CE-02), not an order-of-service fix.
  private func server(singleLine: Bool, diameter: CGFloat) -> some View {
    control(
      "controls.server", systemImage: "arrow.left.arrow.right", fill: .watchSurfaceRaised,
      glyph: .watchTextPrimary, id: "controls.server", singleLine: singleLine, diameter: diameter,
      action: session.correctServer)
  }

  private func end(singleLine: Bool, diameter: CGFloat) -> some View {
    control(
      "controls.end", systemImage: "stop.fill", fill: .watchControlEnd, glyph: .statusEnd,
      id: "controls.end", singleLine: singleLine, diameter: diameter
    ) {
      isConfirmingEnd = true
    }
  }

  private func control(
    _ title: LocalizedStringResource, systemImage: String, fill: Color, glyph: Color,
    id: String, singleLine: Bool, diameter: CGFloat, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: Metrics.circleToLabel) {
        Image(systemName: systemImage)
          .font(.watchTitle)
          .foregroundStyle(glyph)
          .frame(width: diameter, height: diameter)
          .background(fill, in: .circle)
          .accessibilityHidden(true)
          // Read by the UI test of the #21 size decision (research R7 switch).
          .accessibilityIdentifier(
            exposeValues ? id.replacingOccurrences(of: "controls.", with: "controls.circle.") : "")
        Text(title)
          .font(.watchBody)
          .foregroundStyle(Color.watchTextPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(singleLine ? 1 : nil)
          .fixedSize(horizontal: singleLine, vertical: true)
      }
      .frame(maxWidth: .infinity)
      .contentShape(.rect)
    }
    .buttonStyle(ControlButtonStyle())
    .accessibilityLabel(Text(title))
    .accessibilityIdentifier(id)
  }
}

/// Dims a pressed or disabled control.
private struct ControlButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
  }
}

#Preview {
  let session = MatchSession.preview
  session.start(firstServer: .me)
  return ControlsView().environment(session)
}
