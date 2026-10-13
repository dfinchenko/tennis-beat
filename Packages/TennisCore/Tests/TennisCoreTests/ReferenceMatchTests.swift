import Foundation
import Testing

@testable import TennisCore

/// SC-005: reference matches counted by hand. See `Fixtures/reference/README.md`.
@Suite("ReferenceMatches")
struct ReferenceMatchTests {

  struct Reference: Decodable {
    struct Format: Decodable {
      var matchLength: String
      var setLength: Int
      var gameScoring: String
      var matchTieBreak: Bool
    }
    struct SetGames: Decodable {
      var games: [String]
    }

    var origin: String
    var format: Format
    var firstServer: String
    var sets: [SetGames]
    var expectedStats: StatsSnapshot
  }

  static let handScoredName = "hand-scored-denys"

  static var agentBuilt: [String] {
    Fixtures.urls(in: "reference")
      .map { $0.deletingPathExtension().lastPathComponent }
      .filter { $0 != handScoredName && !$0.hasSuffix(".template") }
  }

  static var handScoredFixtureExists: Bool {
    Fixtures.urls(in: "reference").contains {
      $0.deletingPathExtension().lastPathComponent == handScoredName
    }
  }

  /// Total games finished so far; a tie-break and the match tie-break each count as one.
  static func gamesFinished(_ match: Match) -> Int {
    let state = match.state
    let done = state.completedSets.reduce(0) { $0 + $1.games.me + $1.games.opponent }
    return done + state.games.me + state.games.opponent
  }

  static func check(_ name: String) throws {
    let reference = try JSONDecoder().decode(
      Reference.self, from: Fixtures.data(name, in: "reference"))
    let format = try MatchFormat(
      length: try #require(MatchLength(rawValue: reference.format.matchLength)),
      setLength: try #require(SetLength(rawValue: reference.format.setLength)),
      gameScoring: try #require(GameScoring(rawValue: reference.format.gameScoring)),
      matchTieBreak: reference.format.matchTieBreak)
    var m = Match(
      setup: MatchSetup(
        format: format, firstServer: try #require(Player(rawValue: reference.firstServer))))
    var gameNumber = 0
    for set in reference.sets {
      for game in set.games {
        gameNumber += 1
        let finishedBefore = gamesFinished(m)
        for (index, character) in game.enumerated() {
          #expect(
            gamesFinished(m) == finishedBefore,
            "\(name) [\(reference.origin)]: game \(gameNumber) ended before point \(index + 1)")
          m.play(String(character))
        }
        #expect(
          gamesFinished(m) == finishedBefore + 1,
          "\(name) [\(reference.origin)]: game \(gameNumber) did not end at its last point")
      }
    }
    #expect(m.state.status != .inProgress, "\(name): the match is not over")
    #expect(StatsSnapshot(m.stats) == reference.expectedStats, "\(name) [\(reference.origin)]")
  }

  @Test("SC-005 agent-built reference matches", arguments: agentBuilt)
  func sc005AgentBuilt(name: String) throws {
    #expect(Self.agentBuilt.count == 5)
    try Self.check(name)
  }

  @Test("SC-005 hand-scored (Denys)", .enabled(if: handScoredFixtureExists))
  func sc005HandScored() throws {
    try Self.check(Self.handScoredName)
  }
}
