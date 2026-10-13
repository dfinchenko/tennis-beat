import TennisCore

/// The coin toss for the first server (FR-003, research R10).
nonisolated enum CoinToss {
  /// Me or Opponent with equal chance. Production passes `SystemRandomNumberGenerator`.  ITF: SV-01
  static func toss(using generator: inout some RandomNumberGenerator) -> Player {
    Bool.random(using: &generator) ? .me : .opponent
  }

  /// A toss with the system's random generator.
  static func systemToss() -> Player {
    var generator = SystemRandomNumberGenerator()
    return toss(using: &generator)
  }
}
