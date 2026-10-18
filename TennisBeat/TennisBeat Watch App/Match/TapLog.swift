#if DEBUG
  import os

  /// TEMPORARY (lost-tap investigation, #32 decision): every tap the zone handler receives.
  /// Read with `log show --predicate 'subsystem == "com.dfinchenko.TennisBeat.watchkitapp"'`.
  enum TapLog {
    private static let logger = Logger(
      subsystem: "com.dfinchenko.TennisBeat.watchkitapp", category: "tap")

    static func log(_ message: String) {
      logger.log("\(message, privacy: .public)")
    }
  }
#endif
