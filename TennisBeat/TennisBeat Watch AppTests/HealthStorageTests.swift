import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// No heart-rate or energy value is stored by the app (spec 003 SC-007, FR-014, constitution
/// IX; T049): after a match with distinctive values, neither the preferences nor any file in
/// the app container's `Library` and `Documents` holds them.
@MainActor
struct HealthStorageTests {
  /// The match's values: a reading of 187 bpm, and statistics 181 / 197 / 733 kcal.
  static let values = ["187", "181", "197", "733"]

  /// Where `needles` occur: one entry per preferences key or file that holds any of them.
  /// Property lists (preferences, binary or not) are searched as decoded values, so a number
  /// stored as an integer is found too; other files as UTF-8 text.
  static func search(_ needles: [String], defaults: [UserDefaults], directories: [URL])
    -> [String]
  {
    func contains(_ text: String) -> Bool { needles.contains { text.contains($0) } }
    var hits: [String] = []
    for store in defaults {
      for (key, value) in store.dictionaryRepresentation() where contains("\(value)") {
        hits.append("defaults \(key)")
      }
    }
    let manager = FileManager.default
    for directory in directories {
      guard let files = manager.enumerator(at: directory, includingPropertiesForKeys: nil)
      else { continue }
      for case let file as URL in files {
        guard let data = try? Data(contentsOf: file) else { continue }  // folders, locked files
        let text: String
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) {
          text = "\(plist)"
        } else {
          text = String(decoding: data, as: UTF8.self)
        }
        if contains(text) { hits.append(file.path(percentEncoded: false)) }
      }
    }
    return hits
  }

  static var container: [URL] {
    let manager = FileManager.default
    return [
      manager.urls(for: .libraryDirectory, in: .userDomainMask),
      manager.urls(for: .documentDirectory, in: .userDomainMask),
    ].flatMap(\.self)
  }

  @Test("SC-007, FR-014 after a match with Health values, none of them is in the app's storage")
  func nothingStored() async throws {
    let h = WorkoutHarness()
    h.fake.stats = WorkoutStatistics(
      averageHeartRate: 181, maximumHeartRate: 197, activeEnergy: 733)
    h.start()
    h.fake.emit(
      .heartRate(HeartRateReading(bpm: 187, date: h.clock.current)), token: try #require(h.token))
    h.tap("MO")
    #expect(h.session.latestHeartRate?.bpm == 187)  // the values reached the session
    h.win()
    #expect(h.session.summaryStatistics?.activeEnergy == 733)
    h.session.done()
    await settle()
    #expect(h.fake.savedEndDates.count == 1)

    let hits = Self.search(
      Self.values, defaults: [.standard, h.store], directories: Self.container)
    #expect(hits.isEmpty, "\(hits)")
  }

  @Test("SC-007 positive control: a value written on purpose is found by the same search")
  func searchFindsWrittenValues() throws {
    let suite = "HealthStorageTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(Self.search(["733"], defaults: [defaults], directories: []).isEmpty)
    defaults.set(733, forKey: "energy")  // an integer, not text
    #expect(Self.search(["733"], defaults: [defaults], directories: []) == ["defaults energy"])

    let documents = try #require(
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
    try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    let json = documents.appending(path: "probe-\(UUID().uuidString).json")
    let plist = documents.appending(path: "probe-\(UUID().uuidString).plist")
    defer {
      try? FileManager.default.removeItem(at: json)
      try? FileManager.default.removeItem(at: plist)
    }
    try Data(#"{"heartRate":187}"#.utf8).write(to: json)
    try PropertyListSerialization.data(fromPropertyList: ["max": 197], format: .binary, options: 0)
      .write(to: plist)
    let hits = Self.search(["187", "197"], defaults: [], directories: Self.container)
    #expect(hits.contains(json.path(percentEncoded: false)), "\(hits)")
    #expect(hits.contains(plist.path(percentEncoded: false)), "\(hits)")
  }
}
