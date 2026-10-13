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

  static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

  init(arguments: [String]) {
    #if DEBUG
      resetFormat = arguments.contains("-resetFormat")
      exposeValues = arguments.contains("-uiTestExposeValues")
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
