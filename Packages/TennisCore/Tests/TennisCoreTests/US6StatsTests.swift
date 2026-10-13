import Foundation
import Testing

@testable import TennisCore

@Suite("US6 See match stats without typing anything")
struct US6StatsTests {

  static func tally(_ won: Int, _ of: Int) -> Tally { Tally(won: won, of: of) }

  // MARK: Points on serve and return

  @Test("US6 s1 points won on serve and return count every point, tie-breaks included")
  func s1() throws {
    var m = try Match.make(firstServer: .me)
    m.play("MMOMM")  // game 1, Me serving: 4 of 5
    m.play("OMOOO")  // game 2, Opponent serving: 4 of 5
    #expect(m.state.games == pair(1, 1))
    #expect(m.stats.me.pointsWonOnServe == Self.tally(4, 5))
    #expect(m.stats.me.pointsWonOnReturn == Self.tally(1, 5))
    #expect(m.stats.opponent.pointsWonOnServe == Self.tally(4, 5))
    #expect(m.stats.opponent.pointsWonOnReturn == Self.tally(1, 5))

    // Tie-break points count for the player serving each of them.
    var t = try Match.make(firstServer: .me)
    t.reachTieBreak()
    for k in 0..<10 {
      let server = t.state.server
      let before = t.stats[server].pointsWonOnServe.of
      t.point(k.isMultiple(of: 3) ? .opponent : .me)
      #expect(t.stats[server].pointsWonOnServe.of == before + 1, "tie-break point \(k + 1)")
    }
    let served = t.stats.me.pointsWonOnServe.of + t.stats.opponent.pointsWonOnServe.of
    #expect(served == t.pointCount)
  }

  @Test("US6 s2 one player's points served equal the other's points received")
  func s2() throws {
    var m = try Match.make(scoring: .noAd, firstServer: .opponent)
    m.play("MOMOMOM OOOO MMOMOOMO MMMM OMOMOMO")
    for p in Player.allCases {
      let serve = m.stats[p].pointsWonOnServe
      let otherReturn = m.stats[p.other].pointsWonOnReturn
      #expect(serve.of > 0)  // positive control against all-zero stats
      #expect(serve.of == otherReturn.of)
      #expect(serve.won + otherReturn.won == serve.of)
    }
  }

  // MARK: Service games held

  // ITF: BP-03
  @Test("US6 s3 a completed standard game is a service game for its server, held if won")
  func s3() throws {
    var m = try Match.make(firstServer: .me)
    m.winGame(.me)  // Me serves and holds
    m.winGame(.me)  // the Opponent serves and is broken
    #expect(m.stats.me.serviceGamesHeld == Self.tally(1, 1))
    #expect(m.stats.opponent.serviceGamesHeld == Self.tally(0, 1))
  }

  // ITF: BP-03
  @Test("US6 s4 tie-breaks and match tie-breaks are never service games", arguments: [false, true])
  func s4(matchTieBreak: Bool) throws {
    var m = try Match.make(matchTieBreak: true)
    if matchTieBreak {
      m.winSet(.me)
      m.winSet(.opponent)
    } else {
      m.reachTieBreak()
    }
    let before = m.stats.me.serviceGamesHeld.of + m.stats.opponent.serviceGamesHeld.of
    #expect(before == (matchTieBreak ? 12 : 12))  // positive control: the standard games count
    m.play(matchTieBreak ? "MMMMMMMMMM" : "MMMMMMM")
    #expect(m.state.isTieBreak == false)
    let after = m.stats.me.serviceGamesHeld.of + m.stats.opponent.serviceGamesHeld.of
    #expect(after == before)
  }

  // ITF: BP-03
  @Test("US6 s5 a game in progress is not counted yet")
  func s5() throws {
    var m = try Match.make()
    m.play("MMM")
    #expect(m.stats.me.serviceGamesHeld == Self.tally(0, 0))
    m.point(.me)
    #expect(m.stats.me.serviceGamesHeld == Self.tally(1, 1))  // positive control
  }

  // MARK: Break points

  /// Plays `setup` on Me's serve, then one more point by `winner`, and returns how many
  /// break-point opportunities that point added for the Opponent (the receiver).
  static func opportunitiesAdded(
    scoring: GameScoring = .advantage, setup: String, then winner: Player
  ) throws -> Int {
    var m = try Match.make(scoring: scoring, firstServer: .me)
    m.play(setup)
    let before = m.stats.opponent.breakPointsConverted.of
    m.point(winner)
    return m.stats.opponent.breakPointsConverted.of - before
  }

  // ITF: BP-01
  @Test(
    "US6 s6 30-40, 15-40, 0-40 and the receiver's advantage are break points",
    arguments: ["MMOOO", "MOOO", "OOO", "MMMOOO O"])
  func s6(setup: String) throws {
    #expect(try Self.opportunitiesAdded(setup: setup, then: .me) == 1)
    #expect(try Self.opportunitiesAdded(setup: setup, then: .opponent) == 1)
    // Other scores are not break points.
    for other in ["", "MMOO", "OO", "MMMOOO", "MMMOOO M"] {
      #expect(try Self.opportunitiesAdded(setup: other, then: .opponent) == 0, "\(other)")
    }
  }

  // ITF: BP-01, NA-01
  @Test("US6 s7 the No-Ad deciding point is a break point for the receiver")
  func s7() throws {
    #expect(try Self.opportunitiesAdded(scoring: .noAd, setup: "MMMOOO", then: .me) == 1)
  }

  // ITF: BP-02
  @Test("US6 s8 from 0-40 the server wins three points: three break points, all saved")
  func s8() throws {
    var m = try Match.make(firstServer: .me)
    m.play("OOO MMM")
    #expect(m.stats.me.breakPointsSaved == Self.tally(3, 3))
    #expect(m.stats.opponent.breakPointsConverted == Self.tally(0, 3))
  }

  // ITF: BP-02
  @Test("US6 s9 the receiver wins at advantage: the break point is converted")
  func s9() throws {
    var m = try Match.make(firstServer: .me)
    m.play("MMMOOO O")
    let before = m.stats.opponent.breakPointsConverted
    m.point(.opponent)
    let after = m.stats.opponent.breakPointsConverted
    #expect(after.won == before.won + 1)
    #expect(after.of == before.of + 1)
  }

  // ITF: BP-01, BP-02
  @Test("US6 s10 every advantage to the receiver is a separate break point")
  func s10() throws {
    var m = try Match.make(firstServer: .me)
    m.play("MMMOOO OM OM OM OO")
    #expect(m.stats.opponent.breakPointsConverted == Self.tally(1, 4))
    #expect(m.stats.me.breakPointsSaved == Self.tally(3, 4))
  }

  // ITF: BP-02
  @Test("US6 s11 a tie-break point is never a break point, whatever the score")
  func s11() throws {
    var m = try Match.make(firstServer: .opponent)
    m.winGames(me: 6, opponent: 6)  // Me wins game 1 on the Opponent's serve: every game is a break
    let before = m.stats
    #expect(before.me.breakPointsConverted.of + before.opponent.breakPointsConverted.of > 0)
    m.play("OOOOOO MMMMMM OM")
    #expect(m.state.isTieBreak)
    #expect(m.stats.me.breakPointsConverted == before.me.breakPointsConverted)
    #expect(m.stats.opponent.breakPointsConverted == before.opponent.breakPointsConverted)
    #expect(m.stats.me.breakPointsSaved == before.me.breakPointsSaved)
    #expect(m.stats.opponent.breakPointsSaved == before.opponent.breakPointsSaved)
  }

  // ITF: BP-02
  @Test("US6 s12 converted equals the other player's faced minus saved")
  func s12() throws {
    var m = try Match.make(scoring: .noAd, firstServer: .opponent)
    m.play("MMMOOOM MMMOOOO OOOO MOMOMOM OMOMOMM MMMM")
    for p in Player.allCases {
      let converted = m.stats[p].breakPointsConverted
      let saved = m.stats[p.other].breakPointsSaved
      #expect(converted.of > 0)  // positive control
      #expect(converted.of == saved.of)
      #expect(converted.won == saved.of - saved.won)
    }
  }
}

extension US4TieBreakTests {
  // ITF: BP-02
  @Test(
    "US4 s8 no point in a tie-break or match tie-break is a break point", arguments: [false, true])
  func s8(matchTieBreak: Bool) throws {
    var m = try Match.make(matchTieBreak: true, firstServer: .opponent)
    if matchTieBreak {
      m.winSet(.me)
      m.winSet(.opponent)
    } else {
      m.winGames(me: 6, opponent: 6)
    }
    let before = m.stats
    // Positive control: break points before the tie-break are counted.
    #expect(before.me.breakPointsConverted.of + before.opponent.breakPointsConverted.of > 0)
    m.play(String(repeating: "MO", count: 8) + "OO")
    #expect(m.stats.me.breakPointsConverted == before.me.breakPointsConverted)
    #expect(m.stats.opponent.breakPointsConverted == before.opponent.breakPointsConverted)
    #expect(m.stats.me.breakPointsSaved == before.me.breakPointsSaved)
    #expect(m.stats.opponent.breakPointsSaved == before.opponent.breakPointsSaved)
  }
}

extension PropertyTests {
  @Test("SC-006 stats identities hold for every prefix of every generated match")
  func sc006() throws {
    for g in Self.generated {
      guard case .setup(let setup)? = g.events.first else { continue }
      var m = Match(setup: setup)
      for event in g.events.dropFirst() {
        try m.record(event)
        let s = m.stats
        var ok = s.me.pointsWonOnServe.of + s.opponent.pointsWonOnServe.of == m.pointCount
        for p in Player.allCases {
          ok =
            ok && s[p].pointsWonOnServe.of == s[p.other].pointsWonOnReturn.of
            && s[p].pointsWonOnServe.won + s[p.other].pointsWonOnReturn.won
              == s[p].pointsWonOnServe.of
            && s[p].breakPointsConverted.of == s[p.other].breakPointsSaved.of
            && s[p].breakPointsConverted.won
              == s[p.other].breakPointsSaved.of - s[p.other].breakPointsSaved.won
        }
        guard ok else {
          Issue.record("identities broken after \(m.events.count) events, \(Self.label(g))")
          break
        }
      }
    }
  }
}
