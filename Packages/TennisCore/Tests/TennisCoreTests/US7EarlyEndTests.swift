import Foundation
import Testing

@testable import TennisCore

@Suite("US7 End a match early")
struct US7EarlyEndTests {

  /// Best of 3 at 6–4, 3–2, 30–15 (mid-game) or 6–4, 6–6, 3–2 in the tie-break (mid-tie-break).
  static func inProgress(_ where: String) throws -> Match {
    var m = try Match.make()
    m.winGames(me: 6, opponent: 4)
    if `where` == "mid-game" {
      m.winGames(me: 3, opponent: 2)
      m.play("MMO")
    } else {
      m.reachTieBreak()
      m.play("MMMOO")
    }
    return m
  }

  // ITF: MT-08
  @Test(
    "US7 s1 an early end makes the match unfinished and keeps the score",
    arguments: ["mid-game", "mid-tie-break"])
  func s1(where: String) throws {
    var m = try Self.inProgress(`where`)
    let before = m.state
    try m.endEarly()
    #expect(m.state.status == .unfinished)
    #expect(m.state.completedSets.first?.winner == .me)
    #expect(m.state.completedSets.first?.games == pair(6, 4))
    #expect(m.state.games == before.games)
    #expect(m.state.points == before.points)
    if `where` == "mid-game" {
      #expect(m.state.games == pair(3, 2))
      #expect(m.state.points == pts(.thirty, .fifteen))
    }
  }

  // ITF: MT-08, BP-03
  @Test(
    "US7 s2 stats count every point before the early end; the game in progress is not a service game"
  )
  func s2() throws {
    var m = try Self.inProgress("mid-game")
    let before = m.stats
    try m.endEarly()
    #expect(m.state.status == .unfinished)  // positive control
    #expect(m.stats == before)
    #expect(m.stats.me.pointsWonOnServe.of + m.stats.opponent.pointsWonOnServe.of == m.pointCount)
    #expect(m.stats.me.serviceGamesHeld.of + m.stats.opponent.serviceGamesHeld.of == 15)
  }

  // ITF: MT-08
  @Test("US7 s3 a point after an early end is rejected and nothing changes")
  func s3() throws {
    var m = try Self.inProgress("mid-game")
    try m.endEarly()
    #expect(m.state.status == .unfinished)
    let before = m
    #expect(throws: MatchError.matchNotInProgress) { try m.recordPoint(wonBy: .me, at: m.nextTime) }
    #expect(m == before)
  }

  // ITF: MT-08
  @Test("US7 s4 undo of the early end resumes the match at the same score, server and side")
  func s4() throws {
    let original = try Self.inProgress("mid-game")
    var m = original
    try m.endEarly()
    #expect(m.state.status == .unfinished)
    #expect(m.undo() == .matchEndedEarly)
    #expect(m == original)
    #expect(m.state.status == .inProgress)
  }

  // ITF: MT-08
  @Test("US7 s5 an early end at 0-0 is accepted: unfinished with empty stats")
  func s5() throws {
    var m = try Match.make()
    try m.endEarly()
    #expect(m.state.status == .unfinished)
    #expect(m.events.count == 2)
    #expect(m.stats == .zero)
  }

  // ITF: MT-08
  @Test(
    "US7 s6 an early end after a win or after an early end is rejected",
    arguments: ["won", "ended early"])
  func s6(after: String) throws {
    var m = try Match.make(.oneSet)
    if after == "won" {
      m.winSet(.me)
      #expect(m.state.status == .won(.me))
    } else {
      m.play("MO")
      try m.endEarly()
      #expect(m.state.status == .unfinished)  // positive control
    }
    let before = m
    #expect(throws: MatchError.matchNotInProgress) { try m.endEarly() }
    #expect(m == before)
  }

  // ITF: MT-08
  @Test("US7 s7 the early end has no change-of-ends value of its own")
  func s7() throws {
    var m = try Match.make()
    m.play("MMM")
    #expect(!m.state.changeOfEnds)
    try m.endEarly()
    #expect(m.state.status == .unfinished)  // positive control
    #expect(!m.state.changeOfEnds)
  }

  // ITF: MT-08, EN-01
  @Test("US7 s8 an early end, and undoing it, keep the last point's change of ends")
  func s8() throws {
    var m = try Match.make()
    m.winGame(.me)
    #expect(m.state.changeOfEnds)
    try m.endEarly()
    #expect(m.state.status == .unfinished)  // positive control
    #expect(m.state.changeOfEnds)
    m.undo()
    #expect(m.state.status == .inProgress)  // positive control
    #expect(m.state.changeOfEnds)
  }
}

extension US3UndoAndRestoreTests {
  // ITF: MT-08
  @Test("US3 s11 undoing an early end resumes the match and accepts new points")
  func s11() throws {
    var m = try Match.make()
    m.play("MMO")
    let before = m
    try m.endEarly()
    #expect(m.state.status == .unfinished)
    #expect(m.undo() == .matchEndedEarly)
    #expect(m == before)
    m.point(.me)
    #expect(m.state.points == pts(.forty, .fifteen))
  }

  // ITF: MT-08
  @Test("US3 s9 ended early: a point after an early end is rejected and nothing changes")
  func s9EndedEarly() throws {
    // Intentionally the same behaviour as US7 s3, under the US3 ID.
    var m = try Match.make()
    m.play("MO")
    try m.endEarly()
    #expect(m.state.status == .unfinished)
    let before = m
    #expect(throws: MatchError.matchNotInProgress) { try m.recordPoint(wonBy: .me, at: m.nextTime) }
    #expect(m == before)
  }

  // ITF: MT-08
  @Test(
    "US3 s16 a restored list with a point or a second early end after an early end is rejected",
    arguments: [
      #"{"type":"point","winner":"me","recordedAt":5}"#, #"{"type":"matchEndedEarly"}"#,
    ])
  func s16AfterEarlyEnd(extra: String) throws {
    let base =
      #"{"formatVersion":1,"events":[\#(SavedFormatTests.validSetup),{"type":"point","winner":"me","recordedAt":4},{"type":"matchEndedEarly"}"#
    let invalid = Data((base + "," + extra + "]}").utf8)
    #expect(MatchCodec.decode(invalid) == .failure(.invalid(.matchNotInProgress)))
    // Positive control: the list ending with the early end restores as unfinished.
    let valid = try MatchCodec.decode(Data((base + "]}").utf8)).get()
    #expect(valid.state.status == .unfinished)
  }
}

extension PropertyTests {
  @Test("SC-007(b) an early end followed by undo leaves an in-progress match unchanged")
  func sc007b() throws {
    for g in Self.generated {
      guard case .setup(let setup)? = g.events.first else { continue }
      var m = Match(setup: setup)
      for event in g.events.dropFirst() {
        try m.record(event)
        guard m.state.status == .inProgress else { break }
        var ended = m
        try ended.endEarly()
        guard ended.state.status == .unfinished, ended.undo() == .matchEndedEarly, ended == m
        else {
          Issue.record(
            "early end + undo changed the match after \(m.events.count) events, \(Self.label(g))")
          break
        }
      }
    }
  }
}
