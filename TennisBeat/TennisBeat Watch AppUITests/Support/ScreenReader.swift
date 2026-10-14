import TennisCore
import XCTest

/// What the score screen shows for one player (contract §1, §3).
struct ZoneValues: Equatable, CustomStringConvertible {
  var points: String
  var games: String
  var sets: String
  /// `zone.<player>.serve` exists.
  var serves: Bool
  /// `zone.<player>.side`, or nil when absent.
  var side: String?

  var description: String {
    "\(sets) \(games) \(points)" + (serves ? " serve \(side ?? "-")" : "")
  }
}

/// The whole score screen as UI tests see it (research R7, R3-1).
struct ScreenValues: Equatable, CustomStringConvertible {
  var me: ZoneValues
  var opponent: ZoneValues
  /// The `score.summary` label: the VoiceOver summary, then ". <status>" when there is one.
  var summary: String

  var description: String { "Opponent \(opponent) | Me \(me) | \"\(summary)\"" }
}

enum ScreenReader {
  /// Reads the score screen from one accessibility snapshot (one round trip), with the app
  /// launched with `-uiTestExposeValues`. Nil while the screen is not shown.
  @MainActor
  static func read(_ app: XCUIApplication) -> ScreenValues? {
    guard let root = try? app.snapshot() else { return nil }
    var byID: [String: XCUIElementSnapshot] = [:]
    var stack: [XCUIElementSnapshot] = [root]
    while let next = stack.popLast() {
      if !next.identifier.isEmpty, byID[next.identifier] == nil { byID[next.identifier] = next }
      stack.append(contentsOf: next.children)
    }
    func zone(_ player: String) -> ZoneValues? {
      guard let points = byID["zone.\(player).points"]?.label,
        let games = byID["zone.\(player).games"]?.label,
        let sets = byID["zone.\(player).sets"]?.label
      else { return nil }
      return ZoneValues(
        points: points, games: games, sets: sets, serves: byID["zone.\(player).serve"] != nil,
        side: byID["zone.\(player).side"]?.label)
    }
    guard let me = zone("me"), let opponent = zone("opponent"),
      let summary = byID["score.summary"]?.label
    else { return nil }
    return ScreenValues(me: me, opponent: opponent, summary: summary)
  }

  // MARK: Expected values from the engine (contract §3, EN)

  static func expected(_ state: MatchState) -> ScreenValues {
    let status = statusText(state)
    let summary = summaryText(state)
    return ScreenValues(
      me: zone(.me, state), opponent: zone(.opponent, state),
      summary: summary + (status.isEmpty ? "" : ". " + status))
  }

  static func zone(_ player: Player, _ state: MatchState) -> ZoneValues {
    let serves = state.server == player
    return ZoneValues(
      points: points(state.points[player]), games: String(state.games[player]),
      sets: String(state.completedSets.filter { $0.winner == player }.count), serves: serves,
      side: serves ? side(state.courtSide) : nil)
  }

  static func points(_ display: PointDisplay) -> String {
    switch display {
    case .zero: "0"
    case .fifteen: "15"
    case .thirty: "30"
    case .forty: "40"
    case .advantage: "AD"
    case .tieBreak(let n): String(n)
    }
  }

  static func side(_ side: CourtSide) -> String {
    switch side {
    case .right: "Right"
    case .left: "Left"
    case .receiversChoice: "Choice"
    }
  }

  /// Status priority: Match tie-break › Tie-break › Deciding point › Deuce › empty.
  static func statusText(_ state: MatchState) -> String {
    guard state.status == .inProgress else { return "" }
    if state.isMatchTieBreak { return "Match tie-break" }
    if state.isTieBreak { return "Tie-break" }
    if state.isDecidingPoint { return "Deciding point" }
    if state.isDeuce { return "Deuce" }
    return ""
  }

  /// The EN copy-table summary: the server's score first (ITF GM-01), then who serves and
  /// the side (R2-1).
  static func summaryText(_ state: MatchState) -> String {
    func spoken(_ display: PointDisplay) -> String {
      display == .advantage ? "advantage" : points(display)
    }
    let server = state.server
    let score = "\(spoken(state.points[server]))–\(spoken(state.points[server.other]))"
    let who = server == .me ? "I'm serving" : "Opponent serving"
    let side =
      switch state.courtSide {
      case .right: "from the right"
      case .left: "from the left"
      case .receiversChoice: "receiver chooses the side"
      }
    return "\(score), \(who), \(side)"
  }
}
