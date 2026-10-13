import Foundation
import Testing

@testable import TennisCore

/// Loading test fixtures from `Tests/TennisCoreTests/Fixtures`.
enum Fixtures {
  static func data(_ name: String, in directory: String) throws -> Data {
    let url = try #require(
      Bundle.module.url(
        forResource: name, withExtension: "json", subdirectory: "Fixtures/\(directory)"),
      "missing fixture \(directory)/\(name).json")
    return try Data(contentsOf: url)
  }

  static func urls(in directory: String) -> [URL] {
    (Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures/\(directory)")
      ?? [])
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }
}

/// A plain, file-friendly view of `MatchState` (and optionally `MatchStats`) for fixtures.
struct StateSnapshot: Codable, Equatable {
  struct SetSnapshot: Codable, Equatable {
    var games: [Int]
    var tieBreak: [Int]?
    var isMatchTieBreak: Bool
    var winner: String
  }

  var pointCount: Int
  var status: String
  var completedSets: [SetSnapshot]
  var games: [Int]
  var points: [String]
  var server: String
  var courtSide: String
  var isDeuce: Bool
  var isDecidingPoint: Bool
  var isTieBreak: Bool
  var isMatchTieBreak: Bool
  var changeOfEnds: Bool
  var stats: StatsSnapshot?

  init(_ match: Match, includeStats: Bool = false) {
    let state = match.state
    pointCount = match.pointCount
    switch state.status {
    case .inProgress: status = "inProgress"
    case .unfinished: status = "unfinished"
    case .won(let player): status = "won:\(player.rawValue)"
    }
    completedSets = state.completedSets.map {
      SetSnapshot(
        games: [$0.games.me, $0.games.opponent],
        tieBreak: $0.tieBreak.map { [$0.me, $0.opponent] },
        isMatchTieBreak: $0.isMatchTieBreak, winner: $0.winner.rawValue)
    }
    games = [state.games.me, state.games.opponent]
    points = [Self.text(state.points.me), Self.text(state.points.opponent)]
    server = state.server.rawValue
    courtSide =
      switch state.courtSide {
      case .right: "right"
      case .left: "left"
      case .receiversChoice: "receiversChoice"
      }
    isDeuce = state.isDeuce
    isDecidingPoint = state.isDecidingPoint
    isTieBreak = state.isTieBreak
    isMatchTieBreak = state.isMatchTieBreak
    changeOfEnds = state.changeOfEnds
    stats = includeStats ? StatsSnapshot(match.stats) : nil
  }

  static func text(_ display: PointDisplay) -> String {
    switch display {
    case .zero: "0"
    case .fifteen: "15"
    case .thirty: "30"
    case .forty: "40"
    case .advantage: "AD"
    case .tieBreak(let points): "TB\(points)"
    }
  }
}

/// `[won, of]` pairs per stat, per player.
struct StatsSnapshot: Codable, Equatable {
  struct Player: Codable, Equatable {
    var pointsWonOnServe: [Int]
    var pointsWonOnReturn: [Int]
    var serviceGamesHeld: [Int]
    var breakPointsConverted: [Int]
    var breakPointsSaved: [Int]

    init(_ stats: PlayerStats) {
      pointsWonOnServe = [stats.pointsWonOnServe.won, stats.pointsWonOnServe.of]
      pointsWonOnReturn = [stats.pointsWonOnReturn.won, stats.pointsWonOnReturn.of]
      serviceGamesHeld = [stats.serviceGamesHeld.won, stats.serviceGamesHeld.of]
      breakPointsConverted = [stats.breakPointsConverted.won, stats.breakPointsConverted.of]
      breakPointsSaved = [stats.breakPointsSaved.won, stats.breakPointsSaved.of]
    }
  }

  var me: Player
  var opponent: Player

  init(_ stats: MatchStats) {
    me = Player(stats.me)
    opponent = Player(stats.opponent)
  }
}
