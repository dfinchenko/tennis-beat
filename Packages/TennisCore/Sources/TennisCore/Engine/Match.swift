import Foundation

/// A match record (the ordered event list) and the values derived from it.
///
/// Stub (T011): compiles against the full API and never traps; story phases implement it.
public struct Match: Sendable, Hashable {
  public private(set) var events: [MatchEvent]
  public let setup: MatchSetup

  public init(setup: MatchSetup) {
    self.setup = setup
    events = [.setup(setup)]
  }

  /// Replays `events` through `record(_:)`; throws on the first rejected event.
  public init(events: [MatchEvent]) throws(MatchError) {
    guard case .setup(let setup)? = events.first else { throw .missingSetup }
    self.setup = setup
    self.events = events
  }

  public var effectiveFirstServer: Player { setup.firstServer }

  public var state: MatchState {
    MatchState(
      status: .inProgress,
      completedSets: [],
      games: .zero,
      points: PlayerPair(me: .zero, opponent: .zero),
      server: .me,
      courtSide: .right,
      isDeuce: false,
      isDecidingPoint: false,
      isTieBreak: false,
      isMatchTieBreak: false,
      changeOfEnds: false
    )
  }

  public var stats: MatchStats { .zero }

  /// Appends one event. On error, `self` is unchanged.
  public mutating func record(_ event: MatchEvent) throws(MatchError) {}

  public mutating func recordPoint(wonBy winner: Player, at time: Date) throws(MatchError) {
    try record(.point(winner: winner, recordedAt: time))
  }

  public mutating func endEarly() throws(MatchError) {
    try record(.matchEndedEarly)
  }

  public mutating func correctFirstServer(to player: Player) throws(MatchError) {
    try record(.firstServerCorrected(player))
  }

  /// Removes the last non-setup event and returns it; `nil` (no change) with only the setup.
  @discardableResult public mutating func undo() -> MatchEvent? { nil }
}
