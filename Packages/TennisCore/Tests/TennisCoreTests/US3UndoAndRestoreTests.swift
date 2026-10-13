import Foundation
import Testing

@testable import TennisCore

@Suite("US3 Undo any mistake, and resume after a crash")
struct US3UndoAndRestoreTests {

  // ITF: MT-01
  @Test("US3 s9 a point after the match is won is rejected and nothing changes")
  func s9Won() throws {
    var m = try Match.make(.oneSet)
    m.winSet(.me)
    #expect(m.state.status == .won(.me))
    let before = m
    #expect(throws: MatchError.matchNotInProgress) {
      try m.recordPoint(wonBy: .opponent, at: m.nextTime)
    }
    #expect(m == before)
  }
}

extension US3UndoAndRestoreTests {
  /// Matches whose last event crosses a boundary: game, set, tie-break, match tie-break start,
  /// and the match-winning point.
  static func boundaryMatches() throws -> [(String, Match)] {
    var game = try Match.make()
    game.winGame(.me)

    var set = try Match.make()
    set.winGames(me: 6, opponent: 4)

    var intoTieBreak = try Match.make()
    intoTieBreak.reachTieBreak()

    var tieBreakSet = try Match.make()
    tieBreakSet.reachTieBreak()
    tieBreakSet.winTieBreak(.opponent)

    var intoMatchTieBreak = try Match.make(matchTieBreak: true)
    intoMatchTieBreak.winSet(.me)
    intoMatchTieBreak.winSet(.opponent)

    var won = try Match.make(.oneSet, setLength: .four, scoring: .noAd)
    won.winSet(.opponent)

    var wonByMatchTieBreak = try Match.make(matchTieBreak: true)
    wonByMatchTieBreak.winSet(.me)
    wonByMatchTieBreak.winSet(.opponent)
    wonByMatchTieBreak.play("MMMMMMMMMM")

    return [
      ("game", game), ("set", set), ("into tie-break", intoTieBreak),
      ("tie-break set", tieBreakSet), ("into match tie-break", intoMatchTieBreak),
      ("won", won), ("won by match tie-break", wonByMatchTieBreak),
    ]
  }

  @Test("US3 s1 undo removes the last event and equals the state of the remaining events")
  func s1() throws {
    for (name, original) in try Self.boundaryMatches() {
      var m = original
      let removed = m.undo()
      #expect(removed == original.events.last, "\(name)")
      #expect(m.events == Array(original.events.dropLast()), "\(name)")
      let rebuilt = try Match(events: Array(original.events.dropLast()))
      #expect(m.state == rebuilt.state, "\(name)")
      #expect(m.stats == rebuilt.stats, "\(name)")
    }
  }

  // ITF: ST-03
  @Test("US3 s2 undo after winning set 1 6-4 puts set 1 back in progress at 5-4")
  func s2() throws {
    var m = try Match.make()
    m.winGames(me: 5, opponent: 4)
    m.play("MMM")
    let atSetPoint = m.state
    m.point(.me)
    #expect(m.state.completedSets.count == 1)
    m.undo()
    #expect(m.state.completedSets.isEmpty)
    #expect(m.state.games == pair(5, 4))
    #expect(m.state.points == pts(.forty, .zero))
    #expect(m.state == atSetPoint)
  }

  // ITF: MT-01
  @Test("US3 s3 undo of the match-winning point returns to match point; points can be added")
  func s3() throws {
    var m = try Match.make()
    m.winSet(.me)
    m.winGames(me: 5, opponent: 0)
    m.play("MMM")
    let matchPoint = m.state
    m.point(.me)
    #expect(m.state.status == .won(.me))
    m.undo()
    #expect(m.state == matchPoint)
    #expect(m.state.status == .inProgress)
    m.point(.opponent)
    #expect(m.state.points == pts(.forty, .fifteen))
  }

  // ITF: TB-02, TB-04
  @Test("US3 s4 undo at 6-6 in a tie-break gives 6-5 with that point's server and side")
  func s4() throws {
    var m = try Match.make()
    m.reachTieBreak()
    m.play("MOMOMOMOMO M")
    let atSixFive = m.state
    m.point(.opponent)
    #expect(m.state.points == pts(.tieBreak(6), .tieBreak(6)))
    m.undo()
    #expect(m.state.points == pts(.tieBreak(6), .tieBreak(5)))
    #expect(m.state.server == atSixFive.server)
    #expect(m.state.courtSide == atSixFive.courtSide)
    #expect(m.state == atSixFive)
  }

  // ITF: SV-01, SV-03
  @Test(
    "US3 s5 undo of the first point returns to the start of the match", arguments: Player.allCases)
  func s5(first: Player) throws {
    let start = try Match.make(firstServer: first)
    var m = start
    m.point(.opponent)
    m.undo()
    #expect(m == start)
    #expect(m.state.games == pair(0, 0))
    #expect(m.state.server == first)
    #expect(m.state.courtSide == .right)
  }

  @Test("US3 s6 undo with only the setup changes nothing and never removes the setup")
  func s6() throws {
    let start = try Match.make()
    var m = start
    #expect(m.undo() == nil)
    #expect(m == start)
    // Positive control: with a point present, undo returns that point.
    m.point(.me)
    let last = m.events.last
    #expect(m.undo() == last)
    #expect(m.undo() == nil)
    #expect(m.events.count == 1)
  }

  @Test("US3 s10 an event list without a setup, or with a second setup, is rejected")
  func s10() throws {
    let base = try Match.make()
    let setup = MatchEvent.setup(base.setup)
    let point = MatchEvent.point(winner: .me, recordedAt: Date(timeIntervalSinceReferenceDate: 1))
    #expect(throws: MatchError.missingSetup) { try Match(events: []) }
    #expect(throws: MatchError.missingSetup) { try Match(events: [point, setup]) }
    #expect(throws: MatchError.duplicateSetup) { try Match(events: [setup, point, setup]) }
    var m = base
    m.point(.me)
    let before = m
    #expect(throws: MatchError.duplicateSetup) { try m.record(setup) }
    #expect(m == before)
  }

  // ITF: MT-01
  @Test("US3 s16 a restored list with a point after the match-winning point is rejected")
  func s16PointAfterWin() throws {
    var m = try Match.make(.oneSet)
    m.winSet(.me)
    let extra = MatchEvent.point(winner: .opponent, recordedAt: m.nextTime)
    #expect(throws: MatchError.matchNotInProgress) { try Match(events: m.events + [extra]) }
    // Positive control: the list without the extra point is valid and won.
    #expect(try Match(events: m.events).state.status == .won(.me))
  }

  @Test("G1 Match(events: m.events) equals m")
  func g1() throws {
    for (name, m) in try Self.boundaryMatches() {
      #expect(try Match(events: m.events) == m, "\(name)")
    }
  }

  @Test("G2 after undo the match equals Match(events: dropLast)")
  func g2() throws {
    for (name, original) in try Self.boundaryMatches() {
      var m = original
      m.undo()
      #expect(try m == Match(events: Array(original.events.dropLast())), "\(name)")
    }
  }

  @Test("G3 a throwing call leaves the match unchanged")
  func g3() throws {
    var m = try Match.make()
    m.play("MMO")
    let before = m
    #expect(throws: MatchError.duplicateSetup) { try m.record(.setup(m.setup)) }
    #expect(m == before)
  }
}
