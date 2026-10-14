import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// The New match rows and their options (User Story 1 s2, s4; R1-3 of #18).
@MainActor
struct SetupRowTests {
  private func english(_ resource: LocalizedStringResource) -> String {
    var resource = resource
    resource.locale = Locale(identifier: "en")
    return String(localized: resource)
  }

  @Test(
    "US1 s2 each row offers exactly its values, each with its own title",
    arguments: [
      (SetupRow.format, ["oneSet": "1 set", "bestOfThree": "Best of 3"]),
      (SetupRow.setLength, ["four": "4 games", "six": "6 games", "eight": "8 games"]),
      (SetupRow.atFortyAll, ["advantage": "Advantage", "decidingPoint": "Deciding point"]),
      (SetupRow.thirdSet, ["fullSet": "Full set", "tieBreakToTen": "Tie-break to 10"]),
    ])
  func optionTitles(row: SetupRow, expected: [String: String]) {
    let titles = Dictionary(
      uniqueKeysWithValues: row.options.map { ($0.raw, english($0.title)) })
    #expect(titles == expected)
  }

  @Test("US1 s4 the selected option follows the choice, and selecting updates it")
  func selectedOptionFollowsChoice() throws {
    var choice = FormatChoice()
    for row in SetupRow.allCases {
      for option in row.options {
        row.select(option.raw, in: &choice)
        #expect(row.selectedOption(in: choice).raw == option.raw, "\(row)")
      }
    }
    // Positive control: the last pick of each row stuck.
    #expect(choice.length == .bestOfThree)
    #expect(choice.setLength == .eight)
    #expect(choice.atFortyAll == .decidingPoint)
    #expect(choice.thirdSet == .tieBreakToTen)
  }
}
