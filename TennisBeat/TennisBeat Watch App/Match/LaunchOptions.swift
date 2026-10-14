import Foundation
import TennisCore

/// UI-test launch arguments (contract §2). A Release build ignores them all.
nonisolated struct LaunchOptions: Sendable {
  /// `-resetFormat`: forget the stored format, so New match shows the first-use defaults.
  var resetFormat = false
  /// `-coinToss me|opponent`: a fixed coin-toss result.
  var coinToss: Player?
  /// `-uiTestExposeValues`: zone values visible to UI tests (used from the score screen, PR 2).
  var exposeValues = false
  /// `-uiTestAlwaysOn`: the match screens render as in Always On (luminance reduced), for UI
  /// tests and screenshots (PR 5).
  var alwaysOn = false
  /// `-uiTestPoints MMO…`: points played as soon as the match opens (M = Me, O = Opponent),
  /// so UI tests reach a score that Always On, where the zones take no taps, can show.
  var points: [Player] = []

  static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

  init(arguments: [String]) {
    #if DEBUG
      resetFormat = arguments.contains("-resetFormat")
      exposeValues = arguments.contains("-uiTestExposeValues")
      alwaysOn = arguments.contains("-uiTestAlwaysOn")
      if let index = arguments.firstIndex(of: "-uiTestPoints"), index + 1 < arguments.count {
        points = arguments[index + 1].compactMap {
          switch $0 {
          case "M": .me
          case "O": .opponent
          default: nil
          }
        }
      }
      if let index = arguments.firstIndex(of: "-coinToss"), index + 1 < arguments.count {
        switch arguments[index + 1] {
        case "me": coinToss = .me
        case "opponent": coinToss = .opponent
        default: coinToss = nil
        }
      }
    #endif
  }
}
