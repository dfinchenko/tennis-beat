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
        // A 2×2 grid while every label fits on one line; one column otherwise, so long
        // labels (UK «Продовжити» at large sizes) wrap between words, never inside one.
        ViewThatFits(in: .horizontal) {
          Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
              undo(singleLine: true)
              pauseResume(singleLine: true)
            }
            GridRow {
              server(singleLine: true)
              end(singleLine: true)
            }
          }
          VStack(spacing: 8) {
            undo(singleLine: false)
            pauseResume(singleLine: false)
            server(singleLine: false)
            end(singleLine: false)
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

  private func undo(singleLine: Bool) -> some View {
    control(
      "score.undo", systemImage: "arrow.uturn.backward", fill: .watchSurfaceRaised,
      glyph: .watchTextPrimary, id: "controls.undo", singleLine: singleLine,
      action: session.undo
    )
    .disabled(!session.canUndo)
  }

  private func pauseResume(singleLine: Bool) -> some View {
    control(
      session.isPaused ? "controls.resume" : "controls.pause",
      systemImage: session.isPaused ? "play.fill" : "pause.fill", fill: .watchControlPause,
      glyph: .brandBall, id: "controls.pauseResume", singleLine: singleLine
    ) {
      session.isPaused ? session.resume() : session.pause()
    }
  }

  /// The first-server correction (ITF CE-02), not an order-of-service fix.
  private func server(singleLine: Bool) -> some View {
    control(
      "controls.server", systemImage: "arrow.left.arrow.right", fill: .watchSurfaceRaised,
      glyph: .watchTextPrimary, id: "controls.server", singleLine: singleLine,
      action: session.correctServer)
  }

  private func end(singleLine: Bool) -> some View {
    control(
      "controls.end", systemImage: "stop.fill", fill: .watchControlEnd, glyph: .statusEnd,
      id: "controls.end", singleLine: singleLine
    ) {
      isConfirmingEnd = true
    }
  }

  private func control(
    _ title: LocalizedStringResource, systemImage: String, fill: Color, glyph: Color,
    id: String, singleLine: Bool, action: @escaping () -> Void
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
