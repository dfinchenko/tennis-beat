import Foundation
import TennisCore

/// One step of `-uiTestPoints`: a point, Undo or a server correction (spec 002 contract §2).
nonisolated enum LaunchStep: Hashable, Sendable {
  case point(Player)
  case undo
  case correctServer
}

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
  /// `-uiTestPoints MMOUS…`: steps played as soon as the match opens (M = Me, O = Opponent,
  /// U = Undo, S = server correction), so UI tests reach a score that Always On, where the
  /// zones take no taps, can show, and SC-002 taps only the last steps of a sequence (#36).
  var points: [LaunchStep] = []
  /// `-uiTestHealth denied|shouldRequest|granted|failing`: the fake workout service instead
  /// of HealthKit (spec 003, contract §2).
  var healthMode: FakeHealthMode?
  /// `-uiTestHeartRate 142`: one reading when the match starts.
  var heartRate: Int?
  /// `-uiTestWorkoutStats 138,171,612`: the statistics the summary gets; an empty field is
  /// no value.
  var workoutStats: WorkoutStatistics?
  /// `-uiTestSaveFails`: saving the workout fails.
  var saveFails = false
  /// `-uiTestHoldChangeOfEnds`: a scheduled change-of-ends haptic stays pending until the
  /// next command plays or drops it.
  var holdChangeOfEnds = false

  static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

  init(arguments: [String]) {
    #if DEBUG
      resetFormat = arguments.contains("-resetFormat")
      exposeValues = arguments.contains("-uiTestExposeValues")
      alwaysOn = arguments.contains("-uiTestAlwaysOn")
      if let index = arguments.firstIndex(of: "-uiTestPoints"), index + 1 < arguments.count {
        points = arguments[index + 1].compactMap {
          switch $0 {
          case "M": .point(.me)
          case "O": .point(.opponent)
          case "U": .undo
          case "S": .correctServer
          default: nil
          }
        }
      }
      healthMode = Self.value(after: "-uiTestHealth", in: arguments).flatMap(
        FakeHealthMode.init(rawValue:))
      heartRate = Self.value(after: "-uiTestHeartRate", in: arguments).flatMap { Int($0) }
      workoutStats = Self.value(after: "-uiTestWorkoutStats", in: arguments).flatMap(Self.stats)
      saveFails = arguments.contains("-uiTestSaveFails")
      holdChangeOfEnds = arguments.contains("-uiTestHoldChangeOfEnds")
      if let index = arguments.firstIndex(of: "-coinToss"), index + 1 < arguments.count {
        switch arguments[index + 1] {
        case "me": coinToss = .me
        case "opponent": coinToss = .opponent
        default: coinToss = nil
        }
      }
    #endif
  }

  private static func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
      return nil
    }
    return arguments[index + 1]
  }

  /// "average,maximum,kcal"; exactly three fields, an empty one is no value.
  private static func stats(_ text: String) -> WorkoutStatistics? {
    let fields = text.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    guard fields.count == 3 else { return nil }
    return WorkoutStatistics(
      averageHeartRate: Int(fields[0]), maximumHeartRate: Int(fields[1]),
      activeEnergy: Double(fields[2]))
  }
}
