import Foundation
import Testing

@testable import TennisCore

@Suite("US4 Tie-breaks and the match tie-break")
struct US4TieBreakTests {

  /// A best-of-3 match at 1 set all with the match tie-break option, Me won set 1.
  static func atMatchTieBreak() throws -> Match {
    var m = try Match.make(matchTieBreak: true)
    m.winSet(.me)
    m.winSet(.opponent)
    return m
  }

  // ITF: TB-01
  @Test("US4 s1 a tie-break is flagged and scored with numbers")
  func s1() throws {
    var m = try Match.make()
    m.reachTieBreak()
    #expect(m.state.isTieBreak)
    #expect(m.state.points == pts(.tieBreak(0), .tieBreak(0)))
    m.play("MMO")
    #expect(m.state.points == pts(.tieBreak(2), .tieBreak(1)))
  }

  // ITF: TB-01
  @Test("US4 s2 at 6-5 the leader wins the tie-break 7-5 and the set")
  func s2() throws {
    var m = try Match.make()
    m.reachTieBreak()
    m.play("MOMOMOMOMO M")
    #expect(m.state.points == pts(.tieBreak(6), .tieBreak(5)))
    m.point(.me)
    let set = try #require(m.state.completedSets.first)
    #expect(set.tieBreak == pair(7, 5))
    #expect(set.winner == .me)
    #expect(!m.state.isTieBreak)
  }

  // ITF: TB-01
  @Test("US4 s3 at 6-6 the tie-break continues and needs a 2-point margin, no cap")
  func s3() throws {
    var m = try Match.make()
    m.reachTieBreak()
    m.play("MOMOMOMOMOMO")
    #expect(m.state.points == pts(.tieBreak(6), .tieBreak(6)))
    m.point(.opponent)
    #expect(m.state.points == pts(.tieBreak(6), .tieBreak(7)))
    #expect(m.state.isTieBreak)
    m.point(.me)  // 7-7
    for _ in 0..<6 {
      m.play("MO")
      #expect(m.state.isTieBreak)
      #expect(m.state.completedSets.isEmpty)
    }
    #expect(m.state.points == pts(.tieBreak(13), .tieBreak(13)))
    m.play("MM")
    let set = try #require(m.state.completedSets.first)
    #expect(set.tieBreak == pair(15, 13))
  }

  // ITF: MT-03
  @Test("US4 s4 a match tie-break sets both tie-break flags and uses numbers")
  func s4() throws {
    let m = try Self.atMatchTieBreak()
    #expect(m.state.isMatchTieBreak)
    #expect(m.state.isTieBreak)
    #expect(m.state.points == pts(.tieBreak(0), .tieBreak(0)))
  }

  // ITF: MT-03
  @Test("US4 s5 a match tie-break at 9-8 is won 10-8 by the leader, which wins the match")
  func s5() throws {
    var m = try Self.atMatchTieBreak()
    m.play("MOMOMOMOMOMOMOMO M")
    #expect(m.state.points == pts(.tieBreak(9), .tieBreak(8)))
    #expect(m.state.status == .inProgress)
    m.point(.me)
    #expect(m.state.status == .won(.me))
    #expect(m.state.completedSets.last?.tieBreak == pair(10, 8))
  }

  // ITF: MT-03
  @Test("US4 s6 a match tie-break at 9-9 and 10-10 continues until a 2-point margin")
  func s6() throws {
    var m = try Self.atMatchTieBreak()
    m.play(String(repeating: "MO", count: 9))
    #expect(m.state.points == pts(.tieBreak(9), .tieBreak(9)))
    m.play("MO")
    #expect(m.state.points == pts(.tieBreak(10), .tieBreak(10)))
    m.point(.opponent)
    #expect(m.state.status == .inProgress)
    m.point(.opponent)
    #expect(m.state.status == .won(.opponent))
    #expect(m.state.completedSets.last?.tieBreak == pair(10, 12))
  }

  // ITF: MT-05
  @Test("US4 s7 a match won by a match tie-break lists 6-4, 3-6, 10-7")
  func s7() throws {
    var m = try Match.make(matchTieBreak: true)
    m.winGames(me: 6, opponent: 4)
    m.winGames(me: 3, opponent: 6)
    m.play(String(repeating: "MO", count: 7) + "MMM")
    #expect(m.state.status == .won(.me))
    let sets = m.state.completedSets
    try #require(sets.count == 3)
    #expect(sets[0].games == pair(6, 4))
    #expect(sets[1].games == pair(3, 6))
    #expect(sets[2].games == pair(1, 0))
    #expect(sets[2].tieBreak == pair(10, 7))
    #expect(sets[2].isMatchTieBreak)
    #expect(sets[2].winner == .me)
    #expect(!sets[0].isMatchTieBreak && !sets[1].isMatchTieBreak)
  }

  // ITF: TB-01, ST-07
  @Test(
    "US4 s9 a set won in a tie-break records N+1-N and the tie-break score",
    arguments: [
      (SetLength.six, "MOMOMOMOMO MM", 7, 5),
      (SetLength.four, "MOMOMOMOMOMOMO MM", 9, 7),
      (SetLength.eight, "MOMOMO MMMM", 7, 3),
    ])
  func s9(setLength: SetLength, tieBreak: String, me: Int, opponent: Int) throws {
    var m = try Match.make(setLength: setLength)
    m.reachTieBreak()
    m.play(tieBreak)
    let set = try #require(m.state.completedSets.first)
    let n = setLength.rawValue
    #expect(set.games == pair(n + 1, n))
    #expect(set.tieBreak == pair(me, opponent))
    #expect(!set.isMatchTieBreak)
  }

  // ITF: GM-02, NA-01
  @Test(
    "US4 s10 deuce and deciding-point flags are off at equal tie-break scores",
    arguments: [GameScoring.advantage, .noAd], [false, true])
  func s10(scoring: GameScoring, inMatchTieBreak: Bool) throws {
    var m = try Match.make(scoring: scoring, matchTieBreak: true)
    if inMatchTieBreak {
      m.winSet(.me)
      m.winSet(.opponent)
    } else {
      m.reachTieBreak()
    }
    #expect(m.state.isTieBreak)
    for _ in 0..<(inMatchTieBreak ? 9 : 6) {
      m.play("MO")
      let points = m.state.points
      #expect(points.me == points.opponent)
      #expect(!m.state.isDeuce)
      #expect(!m.state.isDecidingPoint)
    }
  }
}

extension US4TieBreakTests {
  // ITF: NA-02, TB-04
  @Test(
    "US4 s10 court side is never the receiver's choice at equal tie-break scores",
    arguments: [GameScoring.advantage, .noAd], [false, true])
  func s10CourtSide(scoring: GameScoring, inMatchTieBreak: Bool) throws {
    var m = try Match.make(scoring: scoring, matchTieBreak: true)
    if inMatchTieBreak {
      m.winSet(.me)
      m.winSet(.opponent)
    } else {
      m.reachTieBreak()
    }
    #expect(m.state.isTieBreak)
    m.point(.me)
    #expect(m.state.courtSide == .left)  // positive control against an always-Right stub
    m.point(.opponent)
    for _ in 0..<(inMatchTieBreak ? 9 : 6) {
      #expect(m.state.courtSide == .right)
      m.play("MO")
    }
  }
}
