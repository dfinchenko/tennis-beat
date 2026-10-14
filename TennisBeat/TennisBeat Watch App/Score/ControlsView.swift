import SwiftUI
import TennisCore

/// Watch 4 — Controls: the elapsed time and four round buttons with labels: Undo,
/// Pause / Resume, Server and End (Story 4, FR-014..FR-018). It scrolls, so large text
/// never clips.
struct ControlsView: View {
  @Environment(MatchSession.self) private var session
  @State private var isConfirmingEnd = false

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        if let clock = session.clock {
          ElapsedTimeView(clock: clock, identifier: "controls.elapsed")
        }
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
          GridRow {
            control(
              "score.undo", systemImage: "arrow.uturn.backward", fill: .watchSurfaceRaised,
              glyph: .watchTextPrimary, id: "controls.undo", action: session.undo
            )
            .disabled(!session.canUndo)
            control(
              session.isPaused ? "controls.resume" : "controls.pause",
              systemImage: session.isPaused ? "play.fill" : "pause.fill",
              fill: .watchControlPause, glyph: .brandBall, id: "controls.pauseResume"
            ) {
              session.isPaused ? session.resume() : session.pause()
            }
          }
          GridRow {
            // The first-server correction (ITF CE-02), not an order-of-service fix.
            control(
              "controls.server", systemImage: "arrow.left.arrow.right",
              fill: .watchSurfaceRaised, glyph: .watchTextPrimary, id: "controls.server",
              action: session.correctServer)
            control(
              "controls.end", systemImage: "stop.fill", fill: .watchControlEnd,
              glyph: .statusEnd, id: "controls.end"
            ) {
              isConfirmingEnd = true
            }
          }
        }
      }
    }
    .confirmationDialog(
      Text("confirm.end.title"), isPresented: $isConfirmingEnd, titleVisibility: .visible
    ) {
      Button(role: .destructive, action: session.endEarly) {
        Text("confirm.end.action")
      }
      // Contract §1; watchOS currently drops identifiers on dialog actions, so UI tests
      // find this button by its label.
      .accessibilityIdentifier("confirm.end")
    }
  }

  private func control(
    _ title: LocalizedStringResource, systemImage: String, fill: Color, glyph: Color,
    id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: systemImage)
          .font(.watchTitle)
          .foregroundStyle(glyph)
          .frame(width: 64, height: 64)
          .background(fill, in: .circle)
          .accessibilityHidden(true)
        Text(title)
          .font(.watchBody)
          .foregroundStyle(Color.watchTextPrimary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
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
