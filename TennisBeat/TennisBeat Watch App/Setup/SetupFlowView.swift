import SwiftUI
import TennisCore

/// Screens pushed during setup.
enum SetupDestination: Hashable {
  case picker(SetupRow)
  case firstServer
  case coinTossResult(Player)
}

/// New match → First server → coin-toss result, in one navigation stack (research R6).
/// Back is the system back button; no match exists until a first server is chosen.
/// Spec 003: the one-time "Workout not saved to Health" notice after Done (FR-015).
struct SetupFlowView: View {
  @Environment(MatchSession.self) private var session
  @State private var path: [SetupDestination] = []

  var body: some View {
    NavigationStack(path: $path) {
      NewMatchView(path: $path)
        .navigationDestination(for: SetupDestination.self) { destination in
          switch destination {
          case .picker(let row): OptionPickerView(row: row)
          case .firstServer: FirstServerView(path: $path)
          case .coinTossResult(let player): CoinTossResultView(result: player)
          }
        }
    }
    // Observed, so it also comes when a save fails while New match is already showing; one
    // flag for any number of failed saves, whichever match they belong to (research R5,
    // #30 P2-2). OK clears it; the setup flow is never blocked.
    .alert(
      Text("health.saveFailed.title"),
      isPresented: Binding(
        get: { session.pendingSaveFailureNotice },
        set: { if !$0 { session.dismissSaveFailureNotice() } })
    ) {
      // Contract §1. An alert's title takes no identifier, and watchOS may drop the button's,
      // so UI tests find both by their labels too.
      Button(action: session.dismissSaveFailureNotice) { Text("health.saveFailed.ok") }
        .accessibilityIdentifier("health.saveFailed.ok")
    }
  }
}
