import SwiftUI

/// Switches on the session's route (research R6).
struct RootView: View {
  @Environment(MatchSession.self) private var session

  var body: some View {
    switch session.route {
    case .setup:
      SetupFlowView()
    case .playing:
      // Placeholder until the score screen (PR 2).
      Text(verbatim: "0–0")
        .font(.watchScore)
        .accessibilityIdentifier("score.placeholder")
    case .summary:
      EmptyView()
    }
  }
}

#Preview {
  RootView()
    .environment(MatchSession.preview)
}
