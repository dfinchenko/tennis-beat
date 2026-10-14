import SwiftUI
import TennisCore

/// Watch 6 — Summary, minimal until PR 4: the result and Done (Story 5 s2, s10).
struct SummaryView: View {
  @Environment(MatchSession.self) private var session

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text(title)
          .font(.watchLargeTitle)
          .foregroundStyle(Color.brandBall)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("summary.title")

        Button(action: session.done) {
          Text("summary.done")
            .font(.watchTitle)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(CapsuleButtonStyle(fill: .brandBall, text: .brandOnBall))
        .accessibilityIdentifier("summary.done")
      }
    }
  }

  private var title: LocalizedStringResource {
    if case .won(let winner) = session.match?.state.status {
      return winner == .me ? "summary.win" : "summary.loss"
    }
    return "summary.win"  // Ended early arrives with PR 3
  }
}
