import SwiftUI
import TennisCore

/// Watch 2 — First server: Me, Opponent or a coin toss (Story 1 s7–s9).  ITF: SV-01
struct FirstServerView: View {
  @Environment(MatchSession.self) private var session
  @Binding var path: [SetupDestination]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text("firstServer.title")
          .font(.watchTitle)
          .foregroundStyle(Color.watchTextPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)

        choice("player.me", fill: .brandBall, text: .brandOnBall, id: "firstServer.me") {
          session.start(firstServer: .me)
        }
        choice(
          "player.opponent", fill: .watchButtonOpponent, text: .brandOpponent,
          id: "firstServer.opponent"
        ) {
          session.start(firstServer: .opponent)
        }
        // A new toss on every tap (Story 1 s10).
        choice(
          "firstServer.coinToss", fill: .watchSurface, text: .watchTextPrimary,
          id: "firstServer.coinToss"
        ) {
          path.append(.coinTossResult(session.tossCoin()))
        }
      }
    }
  }

  private func choice(
    _ title: LocalizedStringResource, fill: Color, text: Color, id: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.watchTitle)
        .frame(maxWidth: .infinity, minHeight: 52)
    }
    .buttonStyle(CapsuleButtonStyle(fill: fill, text: text))
    .accessibilityIdentifier(id)
  }
}

#Preview {
  NavigationStack {
    FirstServerView(path: .constant([]))
  }
  .environment(MatchSession.preview)
}
