import Foundation

/// Why a saved match could not be restored (FR-031).
public enum RestoreError: Error, Sendable, Hashable {
  case unsupportedVersion(found: Int, supported: Int)
  /// Not JSON, missing keys, or an unknown event type.
  case malformed
  /// Well-formed, but breaks a rule.
  case invalid(MatchError)
}

/// Saves and restores a match record. See `specs/001-scoring-engine/contracts/saved-format.md`.
public enum MatchCodec {
  public static let currentFormatVersion = 1

  /// Encodes the record as JSON with sorted keys, so equal matches give equal bytes.
  public static func encode(_ match: Match) throws(EncodingError) -> Data {
    let saved = SavedMatch(
      formatVersion: currentFormatVersion, events: match.events.map(SavedEvent.init))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
      return try encoder.encode(saved)
    } catch let error as EncodingError {
      throw error
    } catch {
      throw EncodingError.invalidValue(
        match, .init(codingPath: [], debugDescription: "\(error)", underlyingError: error))
    }
  }

  /// Restores a record: version check first, then migrations, decoding and validation.
  public static func decode(_ data: Data) -> Result<Match, RestoreError> {
    let decoder = JSONDecoder()
    // 1. The version only, so a newer payload is never parsed further.
    guard let probe = try? decoder.decode(VersionProbe.self, from: data),
      probe.formatVersion >= 1
    else { return .failure(.malformed) }
    // 2.
    guard probe.formatVersion <= currentFormatVersion else {
      return .failure(
        .unsupportedVersion(found: probe.formatVersion, supported: currentFormatVersion))
    }
    // 3.
    guard let current = Migrations.migrate(data, from: probe.formatVersion),
      // 4.
      let saved = try? decoder.decode(SavedMatch.self, from: current)
    else { return .failure(.malformed) }
    do {
      let events = try saved.events.map { event throws(MatchError) in try event.matchEvent() }
      // 5.
      return .success(try Match(events: events))
    } catch {
      return .failure(.invalid(error))
    }
  }
}

// MARK: - JSON layout (formatVersion 1)

private struct VersionProbe: Decodable {
  let formatVersion: Int
}

private struct SavedMatch: Codable {
  let formatVersion: Int
  let events: [SavedEvent]
}

private struct SavedFormat: Codable {
  let matchLength: String
  let setLength: Int
  let gameScoring: String
  let matchTieBreak: Bool

  init(_ format: MatchFormat) {
    matchLength = format.length.rawValue
    setLength = format.setLength.rawValue
    gameScoring = format.gameScoring.rawValue
    matchTieBreak = format.matchTieBreak
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    matchLength = try container.decodeRaw(MatchLength.self, forKey: .matchLength).rawValue
    setLength = try container.decode(Int.self, forKey: .setLength)
    gameScoring = try container.decodeRaw(GameScoring.self, forKey: .gameScoring).rawValue
    matchTieBreak = try container.decode(Bool.self, forKey: .matchTieBreak)
  }
}

/// One event, with a `"type"` discriminator. Hand-written so the layout never depends on
/// compiler-synthesized keys (research R5).
private enum SavedEvent: Codable {
  case setup(format: SavedFormat, firstServer: String)
  case point(winner: String, recordedAt: Double)
  case matchEndedEarly
  case firstServerCorrected(firstServer: String)

  private enum Kind: String, Codable {
    case setup, point, matchEndedEarly, firstServerCorrected
  }

  private enum CodingKeys: String, CodingKey {
    case type, format, firstServer, winner, recordedAt
  }

  init(_ event: MatchEvent) {
    switch event {
    case .setup(let setup):
      self = .setup(format: SavedFormat(setup.format), firstServer: setup.firstServer.rawValue)
    case .point(let winner, let recordedAt):
      // The Date's own stored value, round-tripped bit-exactly (research R6).
      self = .point(
        winner: winner.rawValue, recordedAt: recordedAt.timeIntervalSinceReferenceDate)
    case .matchEndedEarly:
      self = .matchEndedEarly
    case .firstServerCorrected(let player):
      self = .firstServerCorrected(firstServer: player.rawValue)
    }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
    case .setup:
      self = .setup(
        format: try container.decode(SavedFormat.self, forKey: .format),
        firstServer: try container.decodeRaw(Player.self, forKey: .firstServer).rawValue)
    case .point:
      self = .point(
        winner: try container.decodeRaw(Player.self, forKey: .winner).rawValue,
        recordedAt: try container.decode(Double.self, forKey: .recordedAt))
    case .matchEndedEarly:
      self = .matchEndedEarly
    case .firstServerCorrected:
      self = .firstServerCorrected(
        firstServer: try container.decodeRaw(Player.self, forKey: .firstServer).rawValue)
    }
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .setup(let format, let firstServer):
      try container.encode(Kind.setup, forKey: .type)
      try container.encode(format, forKey: .format)
      try container.encode(firstServer, forKey: .firstServer)
    case .point(let winner, let recordedAt):
      try container.encode(Kind.point, forKey: .type)
      try container.encode(winner, forKey: .winner)
      try container.encode(recordedAt, forKey: .recordedAt)
    case .matchEndedEarly:
      try container.encode(Kind.matchEndedEarly, forKey: .type)
    case .firstServerCorrected(let firstServer):
      try container.encode(Kind.firstServerCorrected, forKey: .type)
      try container.encode(firstServer, forKey: .firstServer)
    }
  }

  /// The engine event. Raw values were checked while decoding, so only rule violations throw.
  func matchEvent() throws(MatchError) -> MatchEvent {
    switch self {
    case .setup(let saved, let firstServer):
      // ITF: ST-07 — only set lengths 4, 6 and 8 exist.
      guard let setLength = SetLength(rawValue: saved.setLength),
        let length = MatchLength(rawValue: saved.matchLength),
        let scoring = GameScoring(rawValue: saved.gameScoring)
      else { throw .invalidFormat }
      let format = try MatchFormat(
        length: length, setLength: setLength, gameScoring: scoring,
        matchTieBreak: saved.matchTieBreak)
      return .setup(MatchSetup(format: format, firstServer: Player(rawValue: firstServer) ?? .me))
    case .point(let winner, let recordedAt):
      return .point(
        winner: Player(rawValue: winner) ?? .me,
        recordedAt: Date(timeIntervalSinceReferenceDate: recordedAt))
    case .matchEndedEarly:
      return .matchEndedEarly
    case .firstServerCorrected(let player):
      return .firstServerCorrected(Player(rawValue: player) ?? .me)
    }
  }
}

extension KeyedDecodingContainer {
  /// Decodes a string raw value; an unknown value is a structural (`.malformed`) error.
  fileprivate func decodeRaw<T: RawRepresentable>(_ type: T.Type, forKey key: Key) throws -> T
  where T.RawValue == String {
    let raw = try decode(String.self, forKey: key)
    guard let value = T(rawValue: raw) else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: self, debugDescription: "unknown value \(raw)")
    }
    return value
  }
}
