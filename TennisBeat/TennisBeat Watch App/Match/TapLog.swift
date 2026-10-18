#if DEBUG
  import os

  /// DEBUG only: every zone and Undo action, with the dimmed state, the scene phase, page
  /// changes and the change-of-ends haptic. Kept so the next lost tap in the SC-002 UI tests
  /// can be diagnosed from CI's saved log (Denys, relayed on #33:
  /// https://github.com/dfinchenko/tennis-beat/pull/33#issuecomment-6253707014). Release builds
  /// have none of it. Read with
  /// `log show --predicate 'subsystem == "com.dfinchenko.TennisBeat.watchkitapp" AND category == "tap"'`.
  enum TapLog {
    private static let logger = Logger(
      subsystem: "com.dfinchenko.TennisBeat.watchkitapp", category: "tap")

    static func log(_ message: String) {
      logger.log("\(message, privacy: .public)")
    }
  }
#endif
