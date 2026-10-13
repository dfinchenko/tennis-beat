import Foundation

/// A match record (the ordered event list) and the values derived from it.
///
/// Appending a point is one incremental `Reducer.step`; undo and corrections replay the list
/// (research R2). Parts not yet implemented keep the T011 stub behaviour and never trap.
public struct Match: Sendable, Hashable {
  public private(set) var events: [MatchEvent]
  public let setup: MatchSetup
  /// The latest correction's player, or the setup's first server if there is none [ITF: CE-02].
  public private(set) var effectiveFirstServer: Player
  /// The cached reduction of `events`.
  private(set) var reduction: Reduction

  public init(setup: MatchSetup) {
    self.setup = setup
    events = [.setup(setup)]
    effectiveFirstServer = setup.firstServer
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
    case .matchEndedEarly:
      // ITF: MT-08 — only an in-progress match can end early; nothing else changes.
      guard reduction.status == .inProgress else { throw .matchNotInProgress }
      events.append(event)
      reduction.endedEarly = true
    case .firstServerCorrected(let player):
      // ITF: CE-02 — allowed in any status; the whole match is recomputed from the
      // corrected first server, which leaves the score track untouched (research R1).
      guard player != effectiveFirstServer else { throw .sameFirstServer }
      events.append(event)
      effectiveFirstServer = player
      reduction = Reducer.replay(setup: setup, effectiveFirstServer: player, events: events)
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
    effectiveFirstServer = Self.latestFirstServer(setup: setup, events: events)
    reduction = Reducer.replay(
      setup: setup, effectiveFirstServer: effectiveFirstServer, events: events)
    return removed
  }

  private static func latestFirstServer(setup: MatchSetup, events: [MatchEvent]) -> Player {
    for event in events.reversed() {
      if case .firstServerCorrected(let player) = event { return player }
    }
    return setup.firstServer
  }
}
