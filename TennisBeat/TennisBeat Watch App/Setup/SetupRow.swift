import Foundation

/// One New match setting row (Watch 1): its caption, its options and the current choice.
enum SetupRow: String, CaseIterable, Hashable, Identifiable {
  case format, setLength, atFortyAll, thirdSet

  var id: String { rawValue }

  /// Accessibility identifier (contract §1).
  var identifier: String { "setup.\(rawValue)" }

  var caption: LocalizedStringResource {
    switch self {
    case .format: "setup.format.caption"
    case .setLength: "setup.setLength.caption"
    case .atFortyAll: "setup.atFortyAll.caption"
    case .thirdSet: "setup.thirdSet.caption"
    }
  }

  /// The raw values offered by this row, in display order.
  var options: [String] {
    switch self {
    case .format: FormatChoice.Length.allCases.map(\.rawValue)
    case .setLength: FormatChoice.SetGames.allCases.map(\.rawValue)
    case .atFortyAll: FormatChoice.AtFortyAll.allCases.map(\.rawValue)
    case .thirdSet: FormatChoice.ThirdSet.allCases.map(\.rawValue)
    }
  }

  func selected(in choice: FormatChoice) -> String {
    switch self {
    case .format: choice.length.rawValue
    case .setLength: choice.setLength.rawValue
    case .atFortyAll: choice.atFortyAll.rawValue
    case .thirdSet: choice.thirdSet.rawValue
    }
  }

  func select(_ raw: String, in choice: inout FormatChoice) {
    switch self {
    case .format: choice.length = FormatChoice.Length(rawValue: raw) ?? choice.length
    case .setLength: choice.setLength = FormatChoice.SetGames(rawValue: raw) ?? choice.setLength
    case .atFortyAll:
      choice.atFortyAll = FormatChoice.AtFortyAll(rawValue: raw) ?? choice.atFortyAll
    case .thirdSet: choice.thirdSet = FormatChoice.ThirdSet(rawValue: raw) ?? choice.thirdSet
    }
  }

  /// The localized text for one of this row's raw values.
  func title(for raw: String) -> LocalizedStringResource {
    switch raw {
    case "oneSet": "setup.format.oneSet"
    case "bestOfThree": "setup.format.bestOfThree"
    case "four": "setup.setLength.value \(4)"
    case "six": "setup.setLength.value \(6)"
    case "eight": "setup.setLength.value \(8)"
    case "advantage": "setup.atFortyAll.advantage"
    case "decidingPoint": "setup.atFortyAll.decidingPoint"
    case "tieBreakToTen": "setup.thirdSet.tieBreakToTen"
    default: "setup.thirdSet.fullSet"
    }
  }

  /// The rows New match shows for a choice: Third set only for best of 3 (Story 1 s3).
  static func visible(for choice: FormatChoice) -> [SetupRow] {
    allCases.filter { $0 != .thirdSet || choice.isThirdSetVisible }
  }
}
