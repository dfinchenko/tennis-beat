import SwiftUI

/// The match pages: Controls, then Score; opens on Score. Swiping right shows Controls, as
/// in the Workout app (research R6).
struct MatchPagesView: View {
  private enum Page: Hashable { case controls, score }
  @Environment(MatchSession.self) private var session
  @State private var page = Page.score
  /// `-uiTestPoints` plays once per launch, in the first match only.
  @MainActor private static var playedLaunchPoints = false

  var body: some View {
    TabView(selection: $page) {
      ControlsView()
        .tag(Page.controls)
      ScoreView()
        .tag(Page.score)
    }
    .tabViewStyle(.page)
    .task {
      guard !Self.playedLaunchPoints else { return }
      Self.playedLaunchPoints = true
      for player in LaunchOptions.current.points { session.addPoint(for: player) }
    }
  }
}
