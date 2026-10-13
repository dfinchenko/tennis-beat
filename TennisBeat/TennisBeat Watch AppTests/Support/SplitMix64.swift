import Foundation

/// Deterministic, seedable random number generator for property tests (copied from the TennisCore test support).
struct SplitMix64: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  /// Seed for property tests: `TENNISBEAT_SEED` if set, otherwise a fixed default.
  static var testSeed: UInt64 {
    if let raw = ProcessInfo.processInfo.environment["TENNISBEAT_SEED"], let seed = UInt64(raw) {
      return seed
    }
    return 20_261_013
  }
}
