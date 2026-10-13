import Foundation
import Testing

@testable import TennisCore

@Suite("US5 Change ends at the right time")
struct US5ChangeOfEndsTests {

  /// Plays a standard game for `winner` and returns the change-of-ends value of each point.
  static func gameValues(_ m: inout Match, _ winner: Player) -> [Bool] {
    (0..<4).map { _ in
      m.point(winner)
      return m.state.changeOfEnds
    }
  }

  // ITF: EN-01
  @Test("US5 s1 ends change when a game makes the games played in the set odd")
  func s1() throws {
    var m = try Match.make()
    for game in 1...9 {
      let values = Self.gameValues(&m, game.isMultiple(of: 2) ? .opponent : .me)
      #expect(values.dropLast().allSatisfy { !$0 }, "game \(game) mid-game points")
      #expect(values.last == !game.isMultiple(of: 2), "end of game \(game)")
    }
  }

  // ITF: EN-02
  @Test("US5 s2 a set with an even total reports no change at its end; the change follows game 1")
  func s2() throws {
    var m = try Match.make()
    m.winGames(me: 6, opponent: 4)
    #expect(m.state.completedSets.count == 1)
    #expect(!m.state.changeOfEnds)
    // Positive control: game 1 of the next set calls for a change.
    m.winGame(.opponent)
    #expect(m.state.changeOfEnds)
  }

  // ITF: EN-02
  @Test("US5 s3 a set with an odd total that does not end the match reports a change at its end")
  func s3() throws {
    var m = try Match.make()
    m.winGames(me: 6, opponent: 3)
    #expect(m.state.completedSets.count == 1)
    #expect(m.state.status == .inProgress)
    #expect(m.state.changeOfEnds)
  }

  // ITF: EN-03, EN-04
  @Test(
    "US5 s4 a tie-break set (2N+1 games) not ending the match reports a change after it",
    arguments: [SetLength.four, .six, .eight])
  func s4(setLength: SetLength) throws {
    var m = try Match.make(setLength: setLength)
    m.reachTieBreak()
    m.play("MOMO MMMMM")  // 7-2: 9 tie-break points, not a multiple of 6
    let set = try #require(m.state.completedSets.first)
    #expect(set.games.me + set.games.opponent == 2 * setLength.rawValue + 1)
    #expect(m.state.status == .inProgress)
    #expect(m.state.changeOfEnds)
  }

  // ITF: TB-05
  @Test("US5 s5 in a tie-break ends change after every 6 points while it continues")
  func s5() throws {
    var m = try Match.make()
    m.reachTieBreak()
    for k in 1...18 {
      m.point(k.isMultiple(of: 2) ? .opponent : .me)
      #expect(m.state.changeOfEnds == k.isMultiple(of: 6), "tie-break point \(k)")
    }
    #expect(m.state.isTieBreak)
  }

  // ITF: TB-05, EN-03
  @Test("US5 s6 a set-ending tie-break point that is also a multiple of 6 reports one change")
  func s6() throws {
    var m = try Match.make()
    m.reachTieBreak()
    m.play("MOMOMOMOMO M")
    #expect(!m.state.changeOfEnds)  // 11 points
    m.point(.me)  // 7-5: 12 points, ends set 1 at 7-6
    #expect(m.state.completedSets.count == 1)
    #expect(m.state.changeOfEnds)
    // Exactly one change: the next point (the first of set 2) reports none.
    m.point(.me)
    #expect(!m.state.changeOfEnds)
  }

  // ITF: EN-03, EN-04
  @Test(
    "US5 s7 set 2 won in a tie-break reports a change before the match tie-break",
    arguments: [SetLength.four, .six, .eight])
  func s7(setLength: SetLength) throws {
    var m = try Match.make(setLength: setLength, matchTieBreak: true)
    m.winSet(.me)
    m.reachTieBreak()
    m.play("MOMO OOOOO")  // 2-7 to the Opponent
    #expect(m.state.isMatchTieBreak)
    #expect(m.state.changeOfEnds)
  }

  // ITF: EN-02, EN-04, TB-05
  @Test(
    "US5 s8 set 2 with an even total reports no change; the first comes after 6 match tie-break points",
    arguments: [(SetLength.six, 4), (.four, 2), (.eight, 6)])
  func s8(setLength: SetLength, loserGames: Int) throws {
    var m = try Match.make(setLength: setLength, matchTieBreak: true)
    m.winSet(.me)
    m.winGames(me: loserGames, opponent: setLength.rawValue)
    #expect(m.state.isMatchTieBreak)
    #expect(!m.state.changeOfEnds)
    for k in 1...6 {
      m.point(k.isMultiple(of: 2) ? .opponent : .me)
      #expect(m.state.changeOfEnds == (k == 6), "match tie-break point \(k)")
    }
  }

  // ITF: EN-05
  @Test(
    "US5 s9 the match-winning point never reports a change",
    arguments: ["1-set 6-3", "1-set 7-6", "2-0 with a set-2 tie-break", "match tie-break 10-8"])
  func s9(name: String) throws {
    #expect(try !Match.make().state.changeOfEnds)  // before the first point
    var m: Match
    switch name {
    case "1-set 6-3":
      m = try Match.make(.oneSet)
      m.winGames(me: 5, opponent: 3)
      m.play("MMM")
    case "1-set 7-6":
      m = try Match.make(.oneSet)
      m.reachTieBreak()
      m.play("MMMM MM")
    case "2-0 with a set-2 tie-break":
      m = try Match.make()
      m.winSet(.me)
      m.reachTieBreak()
      m.play("MMMM MM")
    default:
      m = try Match.make(matchTieBreak: true)
      m.winSet(.me)
      m.winSet(.opponent)
      m.play(String(repeating: "MO", count: 8) + "M")  // 9-8 after 17 points
    }
    // Positive control: an earlier point of the same match reported a change (after game 1).
    #expect(
      m.events.indices.dropFirst().contains { index in
        (try? Match(events: Array(m.events.prefix(through: index))))?.state.changeOfEnds == true
      })
    #expect(m.state.status == .inProgress)
    m.point(.me)  // the match-winning point (EN-01, EN-02, EN-03 or TB-05 would apply)
    #expect(m.state.status == .won(.me))
    #expect(!m.state.changeOfEnds)
  }
}

extension US3UndoAndRestoreTests {
  // ITF: EN-01, EN-03, TB-05
  @Test("US3 s7 undoing a change-of-ends point exposes the previous point's value")
  func s7() throws {
    // The point that ends game 1: the previous point reports no change.
    var game = try Match.make()
    game.play("MMM")
    game.point(.me)
    #expect(game.state.changeOfEnds)
    game.undo()
    #expect(!game.state.changeOfEnds)

    // Positive control: a set-1 tie-break won 7-0. Point 6 (6-0) calls for a change (TB-05),
    // and point 7 wins the set 7-6, 13 games (EN-03). Undoing point 7 exposes `true`.
    var tieBreak = try Match.make()
    tieBreak.reachTieBreak()
    tieBreak.play("MMMMMM")
    #expect(tieBreak.state.changeOfEnds)
    tieBreak.point(.me)
    #expect(tieBreak.state.completedSets.count == 1)
    #expect(tieBreak.state.changeOfEnds)
    tieBreak.undo()
    #expect(tieBreak.state.points == pts(.tieBreak(6), .tieBreak(0)))
    #expect(tieBreak.state.changeOfEnds)
  }
}
