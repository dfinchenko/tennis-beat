import Foundation
import Testing

@testable import TennisCore

@Suite("US1 Score a match point by point")
struct US1ScoringTests {

  // MARK: Standard game, Advantage format

  // ITF: GM-01
  @Test("US1 s1 points read 0, 15, 30, 40 and never love")
  func s1() throws {
    var m = try Match.make()
    let expected: [PointDisplay] = [.zero, .fifteen, .thirty, .forty]
    for (index, display) in expected.enumerated() {
      #expect(m.state.points.me == display, "after \(index) points")
      #expect(m.state.points.opponent == .zero)
      m.point(.me)
    }
    #expect(m.state.games == pair(1, 0))
  }

  // ITF: GM-01, GM-02
  @Test("US1 s2 40-30 then the leader wins the game and points reset")
  func s2() throws {
    var m = try Match.make()
    m.play("MMMOO")
    #expect(m.state.points == pts(.forty, .thirty))
    m.point(.me)
    #expect(m.state.games == pair(1, 0))
    #expect(m.state.points == pts(.zero, .zero))
  }

  // ITF: GM-02
  @Test("US1 s3 three points each is deuce")
  func s3() throws {
    var m = try Match.make()
    m.play("MMMOOO")
    #expect(m.state.points == pts(.forty, .forty))
    #expect(m.state.isDeuce)
  }

  // ITF: GM-02
  @Test("US1 s4 from deuce the point winner has advantage and deuce is off")
  func s4() throws {
    var m = try Match.make()
    m.play("MMMOOO O")
    #expect(m.state.points == pts(.forty, .advantage))
    #expect(!m.state.isDeuce)
  }

  // ITF: GM-02
  @Test("US1 s5 advantage lost goes back to deuce")
  func s5() throws {
    var m = try Match.make()
    m.play("MMMOOO O M")
    #expect(m.state.points == pts(.forty, .forty))
    #expect(m.state.isDeuce)
    #expect(m.state.games == pair(0, 0))
  }

  // ITF: GM-02
  @Test("US1 s6 advantage converted wins the game")
  func s6() throws {
    var m = try Match.make()
    m.play("MMMOOO O O")
    #expect(m.state.games == pair(0, 1))
    #expect(m.state.points == pts(.zero, .zero))
  }

  // ITF: GM-02
  @Test("US1 s7 ten deuces, then two points in a row win; no cap on deuces")
  func s7() throws {
    var m = try Match.make()
    m.play("MMMOOO")
    var deuces = 1
    #expect(m.state.isDeuce)
    for _ in 0..<9 {
      m.play("MO")
      #expect(m.state.isDeuce)
      #expect(m.state.games == pair(0, 0))
      deuces += 1
    }
    #expect(deuces == 10)
    m.play("MM")
    #expect(m.state.games == pair(1, 0))
  }

  // MARK: Standard game, No-Ad format

  // ITF: NA-01
  @Test("US1 s8 No-Ad three points each is the deciding point, not deuce")
  func s8() throws {
    var m = try Match.make(scoring: .noAd)
    m.play("MMMOOO")
    #expect(m.state.points == pts(.forty, .forty))
    #expect(m.state.isDecidingPoint)
    #expect(!m.state.isDeuce)
  }

  // ITF: NA-01
  @Test("US1 s9 the deciding point wins the game", arguments: Player.allCases)
  func s9(winner: Player) throws {
    var m = try Match.make(scoring: .noAd)
    m.play("MMMOOO")
    m.point(winner)
    #expect(m.state.games == (winner == .me ? pair(1, 0) : pair(0, 1)))
    #expect(m.state.points == pts(.zero, .zero))
  }

  // MARK: Sets

  // ITF: ST-01, ST-03
  @Test("US1 s10 six games with the opponent on four or fewer wins the set", arguments: 0...4)
  func s10(opponentGames: Int) throws {
    var m = try Match.make()
    m.winGames(me: 6, opponent: opponentGames)
    let set = try #require(m.state.completedSets.first)
    #expect(set.games == pair(6, opponentGames))
    #expect(set.winner == .me)
    #expect(set.tieBreak == nil)
    #expect(m.state.games == pair(0, 0))
  }

  // ITF: ST-03
  @Test("US1 s11 from 5-5 two games in a row win the set 7-5")
  func s11() throws {
    var m = try Match.make()
    m.winGames(me: 5, opponent: 5)
    #expect(m.state.completedSets.isEmpty)
    m.winGames(me: 1, opponent: 0)
    #expect(m.state.completedSets.isEmpty)
    #expect(m.state.games == pair(6, 5))
    m.winGames(me: 1, opponent: 0)
    #expect(m.state.completedSets.first?.games == pair(7, 5))
    #expect(m.state.completedSets.first?.winner == .me)
  }

  // ITF: ST-01, ST-03, TB-01
  @Test("US1 s12 at 6-6 a tie-break is played and its winner wins the set 7-6")
  func s12() throws {
    var m = try Match.make()
    m.reachTieBreak()
    #expect(m.state.isTieBreak)
    #expect(m.state.games == pair(6, 6))
    m.winTieBreak(.opponent)
    #expect(m.state.completedSets.first?.games == pair(6, 7))
    #expect(m.state.completedSets.first?.winner == .opponent)
  }

  // ITF: ST-04, ST-07
  @Test(
    "US1 s13 set length 4 is won at 4-0, 4-1, 4-2 or 5-3",
    arguments: [(4, 0), (4, 1), (4, 2), (5, 3)])
  func s13Wins(me: Int, opponent: Int) throws {
    var m = try Match.make(setLength: .four)
    m.winGames(me: me, opponent: opponent)
    #expect(m.state.completedSets.first?.games == pair(me, opponent))
  }

  // ITF: ST-04, ST-07, TB-01
  @Test("US1 s13 set length 4 continues at 4-3 and plays a tie-break at 4-4 won 5-4")
  func s13Continue() throws {
    var m = try Match.make(setLength: .four)
    m.winGames(me: 4, opponent: 3)
    #expect(m.state.completedSets.isEmpty)
    #expect(m.state.games == pair(4, 3))
    m.winGames(me: 0, opponent: 1)
    #expect(m.state.isTieBreak)
    m.winTieBreak(.me)
    #expect(m.state.completedSets.first?.games == pair(5, 4))
  }

  // ITF: ST-06, ST-07
  @Test(
    "US1 s14 set length 8 is won at 8-0 to 8-6 or at 9-7",
    arguments: [(8, 0), (8, 3), (8, 6), (9, 7)])
  func s14Wins(me: Int, opponent: Int) throws {
    var m = try Match.make(setLength: .eight)
    m.winGames(me: me, opponent: opponent)
    #expect(m.state.completedSets.first?.games == pair(me, opponent))
  }

  // ITF: ST-06, ST-07, TB-01
  @Test("US1 s14 set length 8 continues at 8-7 and plays a tie-break at 8-8 won 9-8")
  func s14Continue() throws {
    var m = try Match.make(setLength: .eight)
    m.winGames(me: 8, opponent: 7)
    #expect(m.state.completedSets.isEmpty)
    m.winGames(me: 0, opponent: 1)
    #expect(m.state.isTieBreak)
    m.winTieBreak(.opponent)
    #expect(m.state.completedSets.first?.games == pair(8, 9))
  }

  // MARK: Match

  // ITF: MT-02
  @Test("US1 s15 a 1-set match is won with the set", arguments: Player.allCases)
  func s15(winner: Player) throws {
    var m = try Match.make(.oneSet)
    m.winSet(winner)
    #expect(m.state.status == .won(winner))
  }

  // ITF: MT-01
  @Test("US1 s16 best of 3 is won at 2-0")
  func s16TwoNil() throws {
    var m = try Match.make()
    m.winSet(.me)
    #expect(m.state.status == .inProgress)
    m.winSet(.me)
    #expect(m.state.status == .won(.me))
    #expect(m.state.completedSets.count == 2)
  }

  // ITF: MT-01
  @Test("US1 s16 best of 3 is won at 2-1 after the third set")
  func s16TwoOne() throws {
    var m = try Match.make()
    m.winSet(.me)
    m.winSet(.opponent)
    #expect(m.state.status == .inProgress)
    m.winSet(.opponent)
    #expect(m.state.status == .won(.opponent))
    #expect(m.state.completedSets.map(\.winner) == [.me, .opponent, .opponent])
  }

  // ITF: MT-03
  @Test("US1 s17 with the match tie-break option at 1-1 the decider is a match tie-break")
  func s17() throws {
    var m = try Match.make(matchTieBreak: true)
    m.winSet(.me)
    m.winSet(.opponent)
    #expect(m.state.isMatchTieBreak)
    #expect(m.state.isTieBreak)
    #expect(m.state.points == pts(.tieBreak(0), .tieBreak(0)))
  }

  // ITF: MT-01
  @Test("US1 s18 without the option at 1-1 a normal third set is played")
  func s18() throws {
    var m = try Match.make(matchTieBreak: false)
    m.winSet(.me)
    m.winSet(.opponent)
    #expect(!m.state.isMatchTieBreak)
    #expect(!m.state.isTieBreak)
    #expect(m.state.points == pts(.zero, .zero))
    m.winGame(.me)
    #expect(m.state.games == pair(1, 0))
  }

  // ITF: MT-02
  @Test("US1 s19 a 1-set match with the match tie-break option is rejected")
  func s19() {
    #expect(throws: MatchError.invalidFormat) {
      try MatchFormat(
        length: .oneSet, setLength: .six, gameScoring: .advantage, matchTieBreak: true)
    }
  }
}
