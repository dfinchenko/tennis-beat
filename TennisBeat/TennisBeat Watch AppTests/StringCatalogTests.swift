import Foundation
import Testing

/// SC-006: every string in the watch app's catalog has PL and UK values,
/// and every plural variation has the categories its language needs.
struct StringCatalogTests {
  private static let catalogURL = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appending(path: "TennisBeat Watch App/Localizable.xcstrings")

  private static let requiredPluralCategories: [String: Set<String>] = [
    "en": ["one", "other"],
    "pl": ["one", "few", "many", "other"],
    "uk": ["one", "few", "many", "other"],
  ]

  private func loadStrings() throws -> [String: [String: Any]] {
    let data = try Data(contentsOf: Self.catalogURL)
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["sourceLanguage"] as? String == "en")
    return try #require(json["strings"] as? [String: [String: Any]])
  }

  @Test("SC-006 the catalog has strings")
  func catalogIsNotEmpty() throws {
    #expect(try !loadStrings().isEmpty)
  }

  @Test("SC-006 every key has EN, PL and UK values, with complete plural forms")
  func everyKeyTranslated() throws {
    for (key, entry) in try loadStrings() {
      // Keys Xcode extracts but that are not shown to users are marked shouldTranslate: false.
      if entry["shouldTranslate"] as? Bool == false { continue }
      let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
      for (language, categories) in Self.requiredPluralCategories {
        guard let localization = localizations[language] else {
          Issue.record("\(key): no \(language) value")
          continue
        }
        if let plural = (localization["variations"] as? [String: Any])?["plural"]
          as? [String: [String: Any]]
        {
          let missing = categories.subtracting(plural.keys)
          #expect(missing.isEmpty, "\(key) [\(language)]: missing plural \(missing.sorted())")
          for (category, form) in plural {
            let value = (form["stringUnit"] as? [String: Any])?["value"] as? String ?? ""
            #expect(!value.isEmpty, "\(key) [\(language)/\(category)]: empty")
          }
        } else {
          let value = (localization["stringUnit"] as? [String: Any])?["value"] as? String ?? ""
          #expect(!value.isEmpty, "\(key) [\(language)]: empty")
        }
      }
    }
  }
}
