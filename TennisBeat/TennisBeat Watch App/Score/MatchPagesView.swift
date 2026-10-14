import SwiftUI

/// The match pages: Controls, then Score; opens on Score. Swiping right shows Controls, as
/// in the Workout app (research R6).
struct MatchPagesView: View {
  private enum Page: Hashable { case controls, score }
  @State private var page = Page.score

  var body: some View {
    TabView(selection: $page) {
      ControlsView()
        .tag(Page.controls)
      ScoreView()
        .tag(Page.score)
    }
    .tabViewStyle(.page)
  }
}
