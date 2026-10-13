# Contract: TennisCore public API (v1)

The Swift surface that the watch and iPhone apps use. The signatures are normative. Bodies and internal types are not part of the contract. The entity semantics are in [data-model.md](../data-model.md).

```swift
// MARK: Players and format
public enum Player: String, Sendable, Hashable, CaseIterable {
  case me, opponent
  public var other: Player { get }
}

public enum MatchLength: String, Sendable, Hashable { case oneSet, bestOfThree }
public enum SetLength: Int, Sendable, Hashable { case four = 4, six = 6, eight = 8 }
public enum GameScoring: String, Sendable, Hashable { case advantage, noAd }

public struct MatchFormat: Sendable, Hashable {
  public let length: MatchLength
  public let setLength: SetLength
  public let gameScoring: GameScoring
  public let matchTieBreak: Bool
  /// Throws `.invalidFormat` when `matchTieBreak` is set for a 1-set match (MT-02).
  public init(length: MatchLength, setLength: SetLength,
              gameScoring: GameScoring, matchTieBreak: Bool) throws(MatchError)
}

public struct MatchSetup: Sendable, Hashable {
  public let format: MatchFormat
  public let firstServer: Player
  public init(format: MatchFormat, firstServer: Player)
}

// MARK: Events
public enum MatchEvent: Sendable, Hashable {
  case setup(MatchSetup)
  case point(winner: Player, recordedAt: Date)
  case matchEndedEarly
  case firstServerCorrected(Player)
}

public enum MatchError: Error, Sendable, Hashable {
  case missingSetup          // list empty or not starting with setup
  case duplicateSetup        // a second setup
  case invalidFormat         // unsupported format (US1 s19, s20)
  case matchNotInProgress    // point or early end after a win or an early end
  case sameFirstServer       // correction to the current first server
}

// MARK: Match (record + derived values)
public struct Match: Sendable, Hashable {
  public init(setup: MatchSetup)
  /// Replays `events` through `record(_:)`; throws on the first rejected event.
  public init(events: [MatchEvent]) throws(MatchError)

  public private(set) var events: [MatchEvent]   // events[0] is always .setup
  public var setup: MatchSetup { get }
  public var effectiveFirstServer: Player { get }
  public var state: MatchState { get }
  public var stats: MatchStats { get }

  /// Appends one event. On error, `self` is unchanged.
  public mutating func record(_ event: MatchEvent) throws(MatchError)
  public mutating func recordPoint(wonBy winner: Player, at time: Date) throws(MatchError)
  public mutating func endEarly() throws(MatchError)
  public mutating func correctFirstServer(to player: Player) throws(MatchError)
  /// Removes the last non-setup event and returns it; `nil` (no change) with only the setup.
  @discardableResult public mutating func undo() -> MatchEvent?
}

// MARK: State (FR-014)
public struct PlayerPair<Value: Sendable & Hashable>: Sendable, Hashable {
  public var me: Value
  public var opponent: Value
  public subscript(player: Player) -> Value { get }
}

public enum PointDisplay: Sendable, Hashable {
  case zero, fifteen, thirty, forty, advantage
  case tieBreak(Int)
}

public enum CourtSide: Sendable, Hashable { case right, left, receiversChoice }
public enum MatchStatus: Sendable, Hashable { case inProgress, won(Player), unfinished }

public struct SetScore: Sendable, Hashable {
  public let games: PlayerPair<Int>
  public let tieBreak: PlayerPair<Int>?
  public let isMatchTieBreak: Bool
  public let winner: Player
}

public struct MatchState: Sendable, Hashable {
  public let status: MatchStatus
  public let completedSets: [SetScore]
  public let games: PlayerPair<Int>
  public let points: PlayerPair<PointDisplay>
  public let server: Player
  public let courtSide: CourtSide
  public let isDeuce: Bool
  public let isDecidingPoint: Bool
  public let isTieBreak: Bool
  public let isMatchTieBreak: Bool
  public let changeOfEnds: Bool
}

// MARK: Stats (FR-024..026)
public struct Tally: Sendable, Hashable { public let won: Int; public let of: Int }

public struct PlayerStats: Sendable, Hashable {
  public let pointsWonOnServe: Tally
  public let pointsWonOnReturn: Tally
  public let serviceGamesHeld: Tally
  public let breakPointsConverted: Tally
  public let breakPointsSaved: Tally
}

public struct MatchStats: Sendable, Hashable {
  public let me: PlayerStats
  public let opponent: PlayerStats
  public subscript(player: Player) -> PlayerStats { get }
}

// MARK: Saved format (see saved-format.md)
public enum RestoreError: Error, Sendable, Hashable {
  case unsupportedVersion(found: Int, supported: Int)
  case malformed                 // not JSON, missing keys, unknown event type
  case invalid(MatchError)       // well-formed but breaks a rule (US1 s20, US3 s10, s16)
}

public enum MatchCodec {
  public static let currentFormatVersion: Int   // 1
  public static func encode(_ match: Match) throws -> Data
  public static func decode(_ data: Data) -> Result<Match, RestoreError>
}
```

## Guarantees

| # | Guarantee | Source |
| --- | --- | --- |
| G1 | `Match(events: m.events)` equals `m`, for every `Match` value `m`. | FR-002, FR-003 |
| G2 | After `undo()`, `m` equals `try Match(events: eventsBefore.dropLast())`. | FR-004 |
| G3 | When a mutating method throws, `m` is unchanged. | FR-005 |
| G4 | `MatchCodec.decode(MatchCodec.encode(m)) == .success(m)`, with `recordedAt` bit-exact. | FR-003, FR-032 |
| G5 | Changing only `recordedAt` values never changes `state` or `stats`. | FR-032, US3 s15 |
| G6 | The API never traps on input; every rejection is a typed error. | FR-005, FR-031 |
| G7 | The module imports only Foundation (no SwiftUI, HealthKit, WatchConnectivity). | Constitution |
