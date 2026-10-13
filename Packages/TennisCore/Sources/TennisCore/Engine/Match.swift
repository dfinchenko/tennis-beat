import Foundation

/// A match record (the ordered event list) and the values derived from it.
///
/// Appending a point is one incremental `Reducer.step`; undo and corrections replay the list
/// (research R2). Parts not yet implemented keep the T011 stub behaviour and never trap.
public struct Match: Sendable, Hashable {
  public private(set) var events: [MatchEvent]
  public let setup: MatchSetup
  /// The cached reduction of `events`.
  private(set) var reduction: Reduction

  public init(setup: MatchSetup) {
    self.setup = setup
    events = [.setup(setup)]
    reduction = Reducer.initial(setup: setup, effectiveFirstServer: setup.firstServer)
  }

  /// Replays `events` through `record(_:)`; throws on the first rejected event.
  ///
  /// Live input and restored lists share this one validation path (research R3), so the
  /// cache comes from the incremental `step` path; P-1 checks it against `Reducer.replay`.
  public init(events: [MatchEvent]) throws(MatchError) {
    guard case .setup(let setup)? = events.first else { throw .missingSetup }
    self.init(setup: setup)
    for event in events.dropFirst() {
      try record(event)
    }
  }

  public var effectiveFirstServer: Player { setup.firstServer }

  public var state: MatchState { reduction.state }

  public var stats: MatchStats { reduction.stats }

  /// Appends one event. On error, `self` is unchanged.
  public mutating func record(_ event: MatchEvent) throws(MatchError) {
    switch event {
    case .setup:
      throw .duplicateSetup
    case .point(let winner, _):
      guard reduction.status == .inProgress else { throw .matchNotInProgress }
      events.append(event)
      Reducer.step(&reduction, winner: winner)
    case .matchEndedEarly, .firstServerCorrected:
      // Stub behaviour until T057 and T063: no change, no throw.
      break
    }
  }

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
  @discardableResult public mutating func undo() -> MatchEvent? {
    guard events.count >= 2 else { return nil }
    let removed = events.removeLast()
    reduction = Reducer.replay(
      setup: setup, effectiveFirstServer: effectiveFirstServer, events: events)
    return removed
  }
}
