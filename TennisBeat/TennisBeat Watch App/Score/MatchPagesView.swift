import SwiftUI

/// The match pages: Controls, then Score; opens on Score. Swiping right shows Controls, as
/// in the Workout app (research R6). The Controls page is filled in PR 3.
struct MatchPagesView: View {
  private enum Page: Hashable { case controls, score }
  @State private var page = Page.score
  @Environment(MatchSession.self) private var session

  var body: some View {
    TabView(selection: $page) {
      VStack {
        if let clock = session.clock { ElapsedTimeView(clock: clock) }
      }
      .tag(Page.controls)
      ScoreView()
        .tag(Page.score)
    }
    .tabViewStyle(.page)
  }
}
