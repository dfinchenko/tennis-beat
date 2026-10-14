import SwiftUI
import TennisCore

/// The coin-toss result on its own screen with one Start button (Q3). Back returns to
/// First server without starting a match (R1-12).
struct CoinTossResultView: View {
  @Environment(MatchSession.self) private var session
  let result: Player

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text("coinToss.result \(String(localized: playerName))")
          .font(.watchTitle)
          .foregroundStyle(Color.watchTextPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("coinToss.result")

        Button {
          session.start(firstServer: result)
        } label: {
          Text("setup.start")
            .font(.watchTitle)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(CapsuleButtonStyle(fill: .brandBall, text: .brandOnBall))
        .accessibilityIdentifier("coinToss.start")
      }
    }
  }

  private var playerName: LocalizedStringResource {
    result == .me ? "player.me" : "player.opponent"
  }
}

#Preview {
  NavigationStack {
    CoinTossResultView(result: .opponent)
  }
  .environment(MatchSession.preview)
}
