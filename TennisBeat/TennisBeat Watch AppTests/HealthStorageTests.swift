import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// No heart-rate or energy value is stored by the app (spec 003 SC-007, FR-014, constitution
/// IX; T049): after a match with distinctive values, neither the preferences nor any file in
/// the app container's `Library` and `Documents` holds them.
/// Serialized: the positive control writes probe files that the other test must not see.
/// The search reads preferences, property lists and text files, which is all the app writes
/// today. When the persistence spec adds a database (SwiftData or SQLite), the search must
/// read that store too (#35 R2-2).
@MainActor
@Suite(.serialized)
struct HealthStorageTests {
  /// The match's values: a reading of 187 bpm, and statistics 181 / 197 / 733 kcal.
  static let values = ["187", "181", "197", "733"]

  /// Where `needles` occur: each preferences key or file that holds any of them, with its
  /// content, so a later search can tell new or changed matches from old ones. Property lists
  /// (preferences, binary or not) are searched as decoded values, so a number stored as an
  /// integer is found too; other files only when they are UTF-8 text. Binary files (system
  /// caches such as the Metal shader cache) are skipped: three digits turn up in them by
  /// chance (#35 R1-2), and the app writes its data as property lists or text.
  static func search(_ needles: [String], defaults: [UserDefaults], directories: [URL])
    -> [String: String]
  {
    func contains(_ text: String) -> Bool { needles.contains { text.contains($0) } }
    var hits: [String: String] = [:]
    for store in defaults {
      for (key, value) in store.dictionaryRepresentation() where contains("\(value)") {
        hits["defaults \(key)"] = "\(value)"
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
        } else if let utf8 = String(data: data, encoding: .utf8) {
          text = utf8
        } else {
          continue
        }
        if contains(text) { hits[file.path(percentEncoded: false)] = text }
      }
    }
    return hits
  }

  /// The matches in `after` that weren't in `before`, or whose content changed.
  static func newOrChanged(_ before: [String: String], _ after: [String: String]) -> [String] {
    after.filter { before[$0.key] != $0.value }.map(\.key).sorted()
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
    // What matches before the match can't come from it (#35 R1-2).
    let before = Self.search(
      Self.values, defaults: [.standard, h.store], directories: Self.container)
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

    let after = Self.search(
      Self.values, defaults: [.standard, h.store], directories: Self.container)
    let hits = Self.newOrChanged(before, after)
    #expect(hits.isEmpty, "\(hits)")
  }

  @Test("SC-007 positive control: a value written on purpose is found by the same search")
  func searchFindsWrittenValues() throws {
    // The registration domain is in memory only, so the probe never reaches a preferences
    // file that another search could see.
    let defaults = try #require(UserDefaults(suiteName: "HealthStorageTests.\(UUID().uuidString)"))
    let empty = Self.search(["733"], defaults: [defaults], directories: [])
    #expect(empty.isEmpty)
    defaults.register(defaults: ["energy": 733])  // an integer, not text
    let stored = Self.search(["733"], defaults: [defaults], directories: [])
    #expect(Self.newOrChanged(empty, stored) == ["defaults energy"])

    let documents = try #require(
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
    try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    let json = documents.appending(path: "probe-\(UUID().uuidString).json")
    let plist = documents.appending(path: "probe-\(UUID().uuidString).plist")
    let binary = documents.appending(path: "probe-\(UUID().uuidString).data")
    defer {
      for file in [json, plist, binary] { try? FileManager.default.removeItem(at: file) }
    }
    // A file that matches before and changes afterwards counts; an unchanged one doesn't.
    try Data(#"{"note":"187 steps"}"#.utf8).write(to: json)
    try Data([0xFF, 0xFE] + Array("197".utf8)).write(to: binary)  // not UTF-8: skipped
    let before = Self.search(["187", "197"], defaults: [], directories: Self.container)
    #expect(before[json.path(percentEncoded: false)] != nil)
    #expect(before[binary.path(percentEncoded: false)] == nil)
    try Data(#"{"heartRate":187}"#.utf8).write(to: json)
    try PropertyListSerialization.data(fromPropertyList: ["max": 197], format: .binary, options: 0)
      .write(to: plist)
    let after = Self.search(["187", "197"], defaults: [], directories: Self.container)
    let hits = Self.newOrChanged(before, after)
    #expect(hits.contains(json.path(percentEncoded: false)), "\(hits)")
    #expect(hits.contains(plist.path(percentEncoded: false)), "\(hits)")
    #expect(Self.newOrChanged(after, after).isEmpty)
  }
}
