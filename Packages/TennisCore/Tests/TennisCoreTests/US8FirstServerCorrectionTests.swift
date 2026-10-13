import Foundation
import Testing

@testable import TennisCore

@Suite("US8 Correct the first server")
struct US8FirstServerCorrectionTests {

  /// The same points replayed from a setup with `first` serving first.
  static func rebuilt(_ m: Match, first: Player) throws -> Match {
    var fresh = Match(setup: MatchSetup(format: m.setup.format, firstServer: first))
    for event in m.events.dropFirst() {
      if case .firstServerCorrected = event { continue }
      try fresh.record(event)
    }
    return fresh
  }

  /// Every value that a correction must not change (FR-030).
  static func serverIndependent(_ s: MatchState) -> [String] {
    [
      "\(s.status)", "\(s.completedSets)", "\(s.games)", "\(s.points)", "\(s.courtSide)",
      "\(s.isDeuce)", "\(s.isDecidingPoint)", "\(s.isTieBreak)", "\(s.isMatchTieBreak)",
      "\(s.changeOfEnds)",
    ]
  }

  // ITF: CE-02, BP-03
  @Test("US8 s1 a correction after two games recomputes as if the Opponent had served first")
  func s1() throws {
    var m = try Match.make(firstServer: .me)
    m.winGame(.me)
    m.winGame(.me)
    try m.correctFirstServer(to: .opponent)
    let fresh = try Self.rebuilt(m, first: .opponent)
    #expect(m.state == fresh.state)
    #expect(m.stats == fresh.stats)
    #expect(m.state.games == pair(2, 0))
    #expect(m.stats.opponent.serviceGamesHeld == Tally(won: 0, of: 1))  // game 1: broken
    #expect(m.stats.me.serviceGamesHeld == Tally(won: 1, of: 1))  // game 2: held
    #expect(m.state.server == .opponent)  // game 3
  }

  // ITF: CE-02, BP-01, BP-02, BP-03
  @Test("US8 s2 serve, return, service-game and break-point stats are all recomputed")
  func s2() throws {
    var m = try Match.make(firstServer: .me)
    m.play("MMOOO MO OM OO  MMMM  OOMMMM  MOMOMM")
    let before = m.stats
    try m.correctFirstServer(to: .opponent)
    #expect(m.stats != before)  // positive control
    #expect(m.stats == (try Self.rebuilt(m, first: .opponent)).stats)
  }

  // ITF: CE-02
  @Test("US8 s3 a correction changes only server-dependent values")
  func s3() throws {
    var m = try Match.make(matchTieBreak: true, firstServer: .me)
    m.winGames(me: 6, opponent: 4)
    m.reachTieBreak()
    m.play("MOMOMOM")
    let original = m
    try m.correctFirstServer(to: .opponent)
    #expect(m.state.server != original.state.server)  // positive control
    #expect(m.effectiveFirstServer == .opponent)
    #expect(Self.serverIndependent(m.state) == Self.serverIndependent(original.state))
    // Every point's change-of-ends value is unchanged (FR-030).
    for count in 2...original.events.count {
      var prefix = try Match(events: Array(original.events.prefix(count)))
      let value = prefix.state.changeOfEnds
      try prefix.correctFirstServer(to: .opponent)
      #expect(prefix.state.changeOfEnds == value, "after \(count) events")
    }
  }

  // ITF: CE-02, TB-02, TB-03
  @Test("US8 s4 a correction during a tie-break follows the corrected order, into the next set")
  func s4() throws {
    var m = try Match.make(firstServer: .me)
    m.reachTieBreak()
    m.play("MOM")
    try m.correctFirstServer(to: .opponent)
    #expect(m.state == (try Self.rebuilt(m, first: .opponent)).state)
    #expect(m.state.server == .opponent)  // points 4 and 5 go to the player who started it (TB-02)
    m.play("MMMMM")  // wins the tie-break 7-1 (8 points)
    #expect(m.state.completedSets.count == 1)
    #expect(m.state.server == .me)  // the tie-break's first receiver serves set 2 (TB-03)
    #expect(m.state == (try Self.rebuilt(m, first: .opponent)).state)
  }

  // ITF: CE-02, SV-02
  @Test("US8 s5 points added after a correction continue in the corrected order")
  func s5() throws {
    var m = try Match.make(firstServer: .me)
    m.winGame(.opponent)
    try m.correctFirstServer(to: .opponent)
    m.winGame(.me)
    m.play("MO")
    #expect(m.state == (try Self.rebuilt(m, first: .opponent)).state)
    #expect(m.state.server == .opponent)
  }

  // ITF: CE-02
  @Test("US8 s6 two corrections back to the original equal the uncorrected match")
  func s6() throws {
    var m = try Match.make(firstServer: .me)
    m.winGames(me: 3, opponent: 2)
    m.play("MOM")
    let original = m
    try m.correctFirstServer(to: .opponent)
    #expect(m.state.server != original.state.server)  // positive control
    try m.correctFirstServer(to: .me)
    #expect(m.state == original.state)
    #expect(m.stats == original.stats)
    #expect(m.effectiveFirstServer == .me)
  }

  // ITF: CE-02
  @Test("US8 s7 a correction to the current first server is rejected")
  func s7() throws {
    var m = try Match.make(firstServer: .me)
    m.play("MO")
    var before = m
    #expect(throws: MatchError.sameFirstServer) { try m.correctFirstServer(to: .me) }
    #expect(m == before)
    try m.correctFirstServer(to: .opponent)
    before = m
    #expect(throws: MatchError.sameFirstServer) { try m.correctFirstServer(to: .opponent) }
    #expect(m == before)
  }

  // ITF: CE-02, MT-08
  @Test(
    "US8 s8 a correction after a win or an early end recomputes stats only",
    arguments: ["won", "ended early"])
  func s8(after: String) throws {
    var m = try Match.make(.oneSet, setLength: .four, firstServer: .me)
    m.winGames(me: 2, opponent: 1)
    if after == "won" {
      m.winGames(me: 2, opponent: 0)
    } else {
      try m.endEarly()
    }
    let status = m.state.status
    let sets = m.state.completedSets
    let stats = m.stats
    try m.correctFirstServer(to: .opponent)
    #expect(m.state.status == status)
    #expect(m.state.completedSets == sets)
    #expect(m.stats != stats)  // recomputed (positive control)
    #expect(m.stats == (try Self.rebuilt(m, first: .opponent)).stats)
  }

  // ITF: CE-02
  @Test("US8 s9 undoing a correction gives the uncorrected match")
  func s9() throws {
    var m = try Match.make(firstServer: .me)
    m.winGames(me: 2, opponent: 1)
    let original = m
    try m.correctFirstServer(to: .opponent)
    #expect(m.state.server != original.state.server)  // positive control
    #expect(m.undo() == .firstServerCorrected(.opponent))
    #expect(m == original)
  }

  // ITF: CE-02, MT-08
  @Test(
    "US8 s10 an early end then a correction: valid; undo removes the correction, then the early end"
  )
  func s10() throws {
    var m = try Match.make(firstServer: .me)
    m.winGames(me: 1, opponent: 2)
    try m.endEarly()
    let unfinished = m
    try m.correctFirstServer(to: .opponent)
    #expect(m.state.status == .unfinished)
    #expect(m.stats == (try Self.rebuilt(m, first: .opponent)).stats)
    #expect(try Match(events: m.events) == m)
    #expect(m.undo() == .firstServerCorrected(.opponent))
    #expect(m == unfinished)
    #expect(m.undo() == .matchEndedEarly)
    #expect(m.state.status == .inProgress)
  }

  // ITF: CE-02, EN-01
  @Test("US8 s11 a correction, and undoing it, keep the last point's change of ends")
  func s11() throws {
    var m = try Match.make(firstServer: .me)
    m.winGame(.me)
    #expect(m.state.changeOfEnds)
    let server = m.state.server
    try m.correctFirstServer(to: .opponent)
    #expect(m.state.server != server)  // positive control
    #expect(m.state.changeOfEnds)
    m.undo()
    #expect(m.state.changeOfEnds)
  }
}

extension US3UndoAndRestoreTests {
  // ITF: CE-02
  @Test("US3 s12 undoing a correction restores the uncorrected server, side and serve stats")
  func s12() throws {
    var m = try Match.make(firstServer: .me)
    m.winGame(.me)
    m.play("MO")
    let original = m
    try m.correctFirstServer(to: .opponent)
    #expect(m.state.server != original.state.server)  // positive control
    m.undo()
    #expect(m.state.server == original.state.server)
    #expect(m.state.courtSide == original.state.courtSide)
    #expect(m.stats == original.stats)
    #expect(m.events.last == original.events.last)
    #expect(m.pointCount == original.pointCount)
  }
}

extension PropertyTests {
  @Test("SC-007(a) a correction and the reverse correction leave the entire state unchanged")
  func sc007a() throws {
    for g in Self.generated {
      guard case .setup(let setup)? = g.events.first else { continue }
      var m = Match(setup: setup)
      for event in g.events.dropFirst() {
        try m.record(event)
        var corrected = m
        let first = m.effectiveFirstServer
        try corrected.correctFirstServer(to: first.other)
        // Positive control: a correction always flips the current server. (Serve tallies can
        // coincide after a swap, e.g. two 5-point games won 4-1 by each side, so they are not used.)
        let changed =
          corrected.effectiveFirstServer != first && corrected.state.server != m.state.server
        try corrected.correctFirstServer(to: first)
        guard changed, corrected.state == m.state, corrected.stats == m.stats,
          corrected.effectiveFirstServer == first
        else {
          Issue.record(
            "correction round trip changed the match after \(m.events.count) events, \(Self.label(g))"
          )
          break
        }
      }
    }
  }
}
