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
struct SetupFlowView: View {
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
  }
}
