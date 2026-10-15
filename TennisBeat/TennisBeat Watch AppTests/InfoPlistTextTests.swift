import Foundation
import Testing

/// FR-004: both apps' Info.plist catalogs carry the spec 003 read text, which names heart
/// rate and active energy (copy table "Info.plist: read", R1-3, T013).
struct InfoPlistTextTests {
  private static let projectFolder = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  static let catalogs = [
    projectFolder.appending(path: "TennisBeat Watch App/InfoPlist.xcstrings"),
    projectFolder.appending(path: "TennisBeat/InfoPlist.xcstrings"),
  ]

  static let readText = [
    "en":
      "Tennis Beat reads your heart rate and active energy to show them during and after a match. Health data stays in the Health app.",
    "pl":
      "Tennis Beat odczytuje Twoje tętno i aktywną energię, aby pokazać je w trakcie meczu i po nim. Dane zdrowotne pozostają w aplikacji Zdrowie.",
    "uk":
      "Tennis Beat зчитує ваш пульс і активну енергію, щоб показати їх під час матчу й після нього. Дані про здоров’я залишаються в програмі «Здоров’я».",
  ]

  static func values(_ key: String, in catalog: URL) throws -> [String: String] {
    let data = try Data(contentsOf: catalog)
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(json["strings"] as? [String: [String: Any]])
    let localizations = try #require(
      strings[key]?["localizations"] as? [String: [String: Any]], "\(key) missing")
    return localizations.compactMapValues {
      ($0["stringUnit"] as? [String: Any])?["value"] as? String
    }
  }

  @Test("FR-004 both catalogs have the new read text in EN, PL and UK", arguments: catalogs)
  func readTextInCatalog(catalog: URL) throws {
    let values = try Self.values("NSHealthShareUsageDescription", in: catalog)
    for (language, expected) in Self.readText {
      #expect(values[language] == expected, "\(catalog.lastPathComponent) [\(language)]")
    }
  }

  @Test("FR-004 the EN read text names heart rate and active energy")
  func readTextNamesTypes() {
    let english = Self.readText["en"] ?? ""
    #expect(english.contains("heart rate") && english.contains("active energy"))
    // Positive control: the spec 002 text names heart rate only, and fails the check.
    let old =
      "Tennis Beat reads your heart rate to show it in your match summary. Health data stays in the Health app."
    #expect(!(old.contains("heart rate") && old.contains("active energy")))
  }
}
