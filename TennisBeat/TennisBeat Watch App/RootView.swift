import SwiftUI

/// Switches on the session's route (research R6).
struct RootView: View {
  @Environment(MatchSession.self) private var session

  var body: some View {
    switch session.route {
    case .setup:
      SetupFlowView()
    case .playing:
      MatchPagesView()
    case .summary:
      SummaryView()
    }
  }
}

#Preview {
  RootView()
    .environment(MatchSession.preview)
}
