import Foundation
import Testing

@testable import TennisCore

@Suite("US2 Know who serves and from which side")
struct US2ServiceAndSideTests {

  /// Expected server of the `index`-th standard game (0-based) when no tie-break was played.
  static func alternating(_ first: Player, game index: Int) -> Player {
    index.isMultiple(of: 2) ? first : first.other
  }

  // MARK: Service order

  // ITF: SV-01
  @Test("US2 s1 the first server serves game 1", arguments: Player.allCases)
  func s1(first: Player) throws {
    let m = try Match.make(firstServer: first)
    #expect(m.state.server == first)
  }

  // ITF: SV-02
  @Test(
    "US2 s2 the other player serves after each standard game, also across sets",
    arguments: [(6, 4), (6, 3)])
  func s2(me: Int, opponent: Int) throws {
    var m = try Match.make(firstServer: .opponent)
    var gamesPlayed = 0
    var left = pair(me, opponent)
    var next: Player = .me
    while left.me + left.opponent > 0 {
      if left[next] == 0 { next = next.other }
      #expect(
        m.state.server == Self.alternating(.opponent, game: gamesPlayed), "game \(gamesPlayed)")
      m.winGame(next)
      left[next] -= 1
      next = next.other
      gamesPlayed += 1
    }
    #expect(m.state.completedSets.count == 1)
    // Game 1 of set 2 continues the alternation across the set boundary.
    #expect(m.state.server == Self.alternating(.opponent, game: gamesPlayed))
    m.winGame(.me)
    #expect(m.state.server == Self.alternating(.opponent, game: gamesPlayed + 1))
  }

  // ITF: TB-02
  @Test("US2 s3 in a tie-break the first server serves one point, then two each")
  func s3() throws {
    var m = try Match.make(firstServer: .me)
    m.reachTieBreak()
    let a = m.state.server
    let b = a.other
    let expected = [a, b, b, a, a, b, b, a, a, b, b, a]
    for (k, server) in expected.enumerated() {
      #expect(m.state.server == server, "tie-break point \(k + 1)")
      m.point(k.isMultiple(of: 2) ? .me : .opponent)
    }
  }

  // ITF: TB-02, SV-02
  @Test(
    "US2 s4 the player due to serve game 2N+1 serves the first tie-break point",
    arguments: [SetLength.four, .six, .eight], Player.allCases)
  func s4(setLength: SetLength, first: Player) throws {
    var m = try Match.make(setLength: setLength, firstServer: first)
    m.reachTieBreak()
    #expect(m.state.isTieBreak)
    #expect(m.state.server == first)
  }

  // ITF: TB-03, SV-04
  @Test(
    "US2 s5 after a tie-break set the tie-break's first receiver serves the next set",
    arguments: ["MMMMMMM", "OOOOOOO", "MOMOMOMOMO MM", "MOMOMOMOMOMO OO"])
  func s5(tieBreak: String) throws {
    var m = try Match.make(firstServer: .me)
    m.reachTieBreak()
    #expect(m.state.server == .me)
    m.play(tieBreak)
    #expect(m.state.completedSets.count == 1)
    #expect(m.state.server == .opponent)
  }

  // ITF: MT-04, SV-02
  @Test(
    "US2 s6 after a standard-game set 2 the match tie-break starts with the player due to serve")
  func s6() throws {
    var m = try Match.make(matchTieBreak: true, firstServer: .me)
    m.winGames(me: 6, opponent: 4)  // 10 games
    m.winGames(me: 3, opponent: 6)  // 9 games: 19 played, game 20 is due to the Opponent
    #expect(m.state.isMatchTieBreak)
    #expect(m.state.server == Self.alternating(.me, game: 19))
    #expect(m.state.server == .opponent)
  }

  // ITF: TB-03, MT-04
  @Test(
    "US2 s7 after a tie-break set 2 the match tie-break starts with that tie-break's first receiver"
  )
  func s7() throws {
    var m = try Match.make(matchTieBreak: true, firstServer: .me)
    m.winGames(me: 6, opponent: 4)  // 10 games: set 2 game 1 is Me's
    m.reachTieBreak()  // 12 more games: the tie-break is due to Me
    #expect(m.state.server == .me)
    m.winTieBreak(.opponent)
    #expect(m.state.isMatchTieBreak)
    #expect(m.state.server == .opponent)
  }

  // ITF: TB-02
  @Test("US2 s8 the match tie-break uses the one-then-two-each rotation")
  func s8() throws {
    var m = try Match.make(matchTieBreak: true, firstServer: .me)
    m.winSet(.me)
    m.winSet(.opponent)
    let a = m.state.server
    let expected = [a, a.other, a.other, a, a, a.other, a.other, a, a, a.other, a.other]
    for (k, server) in expected.enumerated() {
      #expect(m.state.server == server, "match tie-break point \(k + 1)")
      m.point(k.isMultiple(of: 2) ? .me : .opponent)
    }
  }

  // MARK: Court side

  // ITF: SV-03
  @Test("US2 s9 a new standard game starts from the right")
  func s9() throws {
    var m = try Match.make()
    #expect(m.state.courtSide == .right)
    m.point(.me)
    #expect(m.state.courtSide == .left)  // positive control against an always-Right stub
    m.play("MMM")
    #expect(m.state.games == pair(1, 0))
    #expect(m.state.courtSide == .right)
  }

  // ITF: SV-03
  @Test(
    "US2 s10 odd points played serve from the left, even from the right",
    arguments: [
      ("M", CourtSide.left), ("MMO", .left), ("MMMO O", .left),
      ("MO", .right), ("MM", .right), ("MMMOOO", .right),
    ])
  func s10(points: String, side: CourtSide) throws {
    var m = try Match.make()
    m.play(points)
    #expect(m.state.courtSide == side)
  }

  // ITF: SV-03, GM-02
  @Test("US2 s11 at advantage (7 points) the side is Left; at the next deuce Right")
  func s11() throws {
    var m = try Match.make()
    m.play("MMMOOO O")
    #expect(m.state.points == pts(.forty, .advantage))
    #expect(m.state.courtSide == .left)
    m.point(.me)
    #expect(m.state.courtSide == .right)
  }

  // ITF: NA-02
  @Test("US2 s12 the No-Ad deciding point is the receiver's choice")
  func s12() throws {
    var m = try Match.make(scoring: .noAd)
    m.play("MMMOOO")
    #expect(m.state.courtSide == .receiversChoice)
  }

  // ITF: TB-04
  @Test(
    "US2 s13 tie-breaks serve from the right on even points played and the left on odd",
    arguments: [false, true])
  func s13(matchTieBreak: Bool) throws {
    var m = try Match.make(matchTieBreak: true)
    if matchTieBreak {
      m.winSet(.me)
      m.winSet(.opponent)
    } else {
      m.reachTieBreak()
    }
    #expect(m.state.isTieBreak)
    for k in 0..<12 {
      #expect(m.state.courtSide == (k.isMultiple(of: 2) ? .right : .left), "points played \(k)")
      m.point(k.isMultiple(of: 2) ? .me : .opponent)
    }
  }
}
