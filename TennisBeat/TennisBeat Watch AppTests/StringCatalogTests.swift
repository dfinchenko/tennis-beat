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

  /// The onboarding rows of the spec 003 copy table (FR-002, US6 s3).
  static let onboardingCopy: [String: [String: String]] = [
    "health.onboarding.title": [
      "en": "Matches as workouts in Health",
      "pl": "Mecze jako treningi w Zdrowiu",
      "uk": "Матчі як тренування в «Здоров’ї»",
    ],
    "health.onboarding.line.1": [
      "en": "Each match is saved as a tennis workout in the Health app.",
      "pl": "Każdy mecz zapisuje się w aplikacji Zdrowie jako trening tenisowy.",
      "uk": "Кожен матч зберігається в програмі «Здоров’я» як тренування з тенісу.",
    ],
    "health.onboarding.line.2": [
      "en": "Heart rate and active energy are shown during and after the match.",
      "pl": "Tętno i aktywna energia są widoczne w trakcie meczu i po nim.",
      "uk": "Пульс і активну енергію видно під час матчу й після нього.",
    ],
    "health.onboarding.line.3": [
      "en": "Data stays in Health. Tennis Beat sends nothing anywhere.",
      "pl": "Dane zostają w Zdrowiu. Tennis Beat niczego nigdzie nie wysyła.",
      "uk": "Дані лишаються в «Здоров’ї». Tennis Beat нікуди нічого не надсилає.",
    ],
    "health.onboarding.continue": ["en": "Continue", "pl": "Dalej", "uk": "Продовжити"],
    "health.onboarding.notNow": ["en": "Not now", "pl": "Nie teraz", "uk": "Не зараз"],
  ]

  @Test("FR-002 onboarding strings equal the copy table in EN, PL and UK")
  func onboardingStrings() throws {
    let strings = try loadStrings()
    for (key, languages) in Self.onboardingCopy {
      let entry = try #require(strings[key], "\(key) is missing")
      let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
      for (language, expected) in languages {
        let value =
          (localizations[language]?["stringUnit"] as? [String: Any])?["value"] as? String
        #expect(value == expected, "\(key) [\(language)]")
      }
    }
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
