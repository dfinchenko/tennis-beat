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

  /// One value a row offers: its stored raw value and its title.
  struct Option: Identifiable {
    let raw: String
    let title: LocalizedStringResource
    var id: String { raw }
  }

  /// The values offered by this row, in display order.
  var options: [Option] {
    switch self {
    case .format: FormatChoice.Length.allCases.map(Option.init)
    case .setLength: FormatChoice.SetGames.allCases.map(Option.init)
    case .atFortyAll: FormatChoice.AtFortyAll.allCases.map(Option.init)
    case .thirdSet: FormatChoice.ThirdSet.allCases.map(Option.init)
    }
  }

  func selectedOption(in choice: FormatChoice) -> Option {
    switch self {
    case .format: Option(choice.length)
    case .setLength: Option(choice.setLength)
    case .atFortyAll: Option(choice.atFortyAll)
    case .thirdSet: Option(choice.thirdSet)
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

  /// The rows New match shows for a choice: Third set only for best of 3 (Story 1 s3).
  static func visible(for choice: FormatChoice) -> [SetupRow] {
    allCases.filter { $0 != .thirdSet || choice.isThirdSetVisible }
  }
}

/// A row value with a title of its own; every case is listed, so none can fall back to
/// another's text (R1-3 of #18).
protocol SetupOptionValue: RawRepresentable<String> {
  var title: LocalizedStringResource { get }
}

extension SetupRow.Option {
  init(_ value: some SetupOptionValue) {
    self.init(raw: value.rawValue, title: value.title)
  }
}

extension FormatChoice.Length: SetupOptionValue {
  var title: LocalizedStringResource {
    switch self {
    case .oneSet: "setup.format.oneSet"
    case .bestOfThree: "setup.format.bestOfThree"
    }
  }
}

extension FormatChoice.SetGames: SetupOptionValue {
  var title: LocalizedStringResource {
    switch self {
    case .four: "setup.setLength.value \(4)"
    case .six: "setup.setLength.value \(6)"
    case .eight: "setup.setLength.value \(8)"
    }
  }
}

extension FormatChoice.AtFortyAll: SetupOptionValue {
  var title: LocalizedStringResource {
    switch self {
    case .advantage: "setup.atFortyAll.advantage"
    case .decidingPoint: "setup.atFortyAll.decidingPoint"
    }
  }
}

extension FormatChoice.ThirdSet: SetupOptionValue {
  var title: LocalizedStringResource {
    switch self {
    case .fullSet: "setup.thirdSet.fullSet"
    case .tieBreakToTen: "setup.thirdSet.tieBreakToTen"
    }
  }
}
