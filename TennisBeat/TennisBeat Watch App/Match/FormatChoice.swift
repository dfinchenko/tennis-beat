import Foundation
import TennisCore

/// The four New match rows (data-model.md § FormatChoice).
///
/// App-side values, so the stored strings don't depend on the engine's types.
nonisolated struct FormatChoice: Hashable, Sendable {
  enum Length: String, CaseIterable, Sendable { case oneSet, bestOfThree }
  enum SetGames: String, CaseIterable, Sendable { case four, six, eight }
  enum AtFortyAll: String, CaseIterable, Sendable { case advantage, decidingPoint }
  enum ThirdSet: String, CaseIterable, Sendable { case fullSet, tieBreakToTen }

  // First-use defaults (Q2): best of 3, sets of 6, Advantage, third set as a full set.
  var length: Length = .bestOfThree
  var setLength: SetGames = .six
  var atFortyAll: AtFortyAll = .advantage
  var thirdSet: ThirdSet = .fullSet

  static let defaults = FormatChoice()

  /// All 2 × 3 × 2 × 2 choices.
  static let allCombinations: [FormatChoice] = Length.allCases.flatMap { length in
    SetGames.allCases.flatMap { setLength in
      AtFortyAll.allCases.flatMap { atFortyAll in
        ThirdSet.allCases.map { thirdSet in
          FormatChoice(
            length: length, setLength: setLength, atFortyAll: atFortyAll, thirdSet: thirdSet)
        }
      }
    }
  }

  /// The Third set row applies to best of 3 only; its value is kept while hidden.  ITF: MT-02
  var isThirdSetVisible: Bool { length == .bestOfThree }

  /// The engine format. `nil` can't occur for any combination (tested); callers still guard it.
  var matchFormat: MatchFormat? {
    let engineLength: MatchLength = length == .oneSet ? .oneSet : .bestOfThree
    let engineSetLength: SetLength =
      switch setLength {
      case .four: .four
      case .six: .six
      case .eight: .eight
      }
    return try? MatchFormat(
      length: engineLength,
      setLength: engineSetLength,
      gameScoring: atFortyAll == .advantage ? .advantage : .noAd,
      matchTieBreak: length == .bestOfThree && thirdSet == .tieBreakToTen)  // ITF: MT-02
  }
}

/// Stores the format of the last started match (FR-004), the only data this feature keeps.
nonisolated struct FormatStore {
  static let key = "lastFormat.v1"
  let defaults: UserDefaults

  /// Each row falls back to its own default when its value is missing or unknown (Story 1 s6).
  func load() -> FormatChoice {
    let stored = defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
    let fallback = FormatChoice.defaults
    return FormatChoice(
      length: stored["length"].flatMap(FormatChoice.Length.init) ?? fallback.length,
      setLength: stored["setLength"].flatMap(FormatChoice.SetGames.init) ?? fallback.setLength,
      atFortyAll: stored["atFortyAll"].flatMap(FormatChoice.AtFortyAll.init)
        ?? fallback.atFortyAll,
      thirdSet: stored["thirdSet"].flatMap(FormatChoice.ThirdSet.init) ?? fallback.thirdSet)
  }

  func save(_ choice: FormatChoice) {
    defaults.set(
      [
        "length": choice.length.rawValue,
        "setLength": choice.setLength.rawValue,
        "atFortyAll": choice.atFortyAll.rawValue,
        "thirdSet": choice.thirdSet.rawValue,
      ], forKey: Self.key)
  }

  func reset() {
    defaults.removeObject(forKey: Self.key)
  }
}
