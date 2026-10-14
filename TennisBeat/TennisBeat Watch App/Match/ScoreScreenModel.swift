import Foundation
import TennisCore

/// Everything Watch 3 shows or reads, built from the engine state, the pause and the
/// language (data-model.md § ScoreScreenModel, FR-006..FR-009, Story 7 s1). Views don't
/// format scores.
nonisolated struct ScoreScreenModel: Hashable, Sendable {
  struct Zone: Hashable, Sendable {
    let player: Player
    /// "Me" / "Opponent".
    let label: String
    /// 0, 15, 30, 40, "AD", or a tie-break number.  ITF: GM-01, TB-01
    let points: String
    let games: Int
    let sets: Int
    let isServer: Bool
    /// "Right" / "Left" / "Choice" for the server, nil for the receiver.  ITF: SV-03, TB-04, NA-02
    let courtSide: String?
    let accessibilityLabel: String
    let accessibilityHint: String
  }

  /// Opponent on top, then Me (FR-005).
  let zones: [Zone]
  /// The status line: "Paused", a game state, or empty (FR-008).
  let statusText: String
  /// "Paused. <state>", "<state>" or empty (R1-3).
  let statusAccessibilityText: String
  /// Read first: the server's score, who serves and the side, then the status (Story 7 s1, s2).
  let summaryAccessibilityLabel: String

  subscript(player: Player) -> Zone {
    zones.first { $0.player == player }!
  }

  init(state: MatchState, isPaused: Bool, locale: Locale) {
    func text(_ resource: LocalizedStringResource) -> String {
      Self.text(resource, locale: locale)
    }
    func name(_ player: Player) -> String {
      text(player == .me ? "player.me" : "player.opponent")
    }

    let gameState = Self.gameState(state).map(text) ?? ""
    statusText = isPaused ? text("status.paused") : gameState
    statusAccessibilityText =
      if isPaused {
        gameState.isEmpty ? text("status.paused") : text("status.paused.state \(gameState)")
      } else { gameState }

    let server = state.server
    let serverPoints = Self.spoken(state.points[server], locale: locale)
    let receiverPoints = Self.spoken(state.points[server.other], locale: locale)
    let summary: LocalizedStringResource =
      switch (server, state.courtSide) {
      case (.me, .right): "score.summary.me.right \(serverPoints) \(receiverPoints)"
      case (.me, .left): "score.summary.me.left \(serverPoints) \(receiverPoints)"
      case (.me, .receiversChoice): "score.summary.me.choice \(serverPoints) \(receiverPoints)"
      case (.opponent, .right): "score.summary.opponent.right \(serverPoints) \(receiverPoints)"
      case (.opponent, .left): "score.summary.opponent.left \(serverPoints) \(receiverPoints)"
      case (.opponent, .receiversChoice):
        "score.summary.opponent.choice \(serverPoints) \(receiverPoints)"
      }
    summaryAccessibilityLabel =
      text(summary) + (statusAccessibilityText.isEmpty ? "" : ". " + statusAccessibilityText)

    zones = [Player.opponent, .me].map { player in
      let isServer = player == server
      let sets = state.completedSets.filter { $0.winner == player }.count
      let games = state.games[player]
      let label = name(player)
      let sentence = text(
        "score.zone \(label) \(Self.spoken(state.points[player], locale: locale)) \(Self.gamesPhrase(games, locale: locale)) \(Self.setsPhrase(sets, locale: locale))"
      )
      let serving: String? =
        if isServer {
          switch state.courtSide {
          case .right: text("score.zone.serving.right")
          case .left: text("score.zone.serving.left")
          case .receiversChoice: text("score.zone.serving.choice")
          }
        } else { nil }
      return Zone(
        player: player, label: label, points: Self.display(state.points[player], locale: locale),
        games: games, sets: sets, isServer: isServer,
        courtSide: isServer ? text(Self.side(state.courtSide)) : nil,
        accessibilityLabel: [sentence, serving].compactMap(\.self).joined(separator: " "),
        accessibilityHint: text("score.zone.hint \(label)"))
    }
  }

  // MARK: Pieces (also used by the session's announcements)

  static func text(_ resource: LocalizedStringResource, locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
  }

  /// The game state for the status line, by priority (FR-008). A match tie-break shows only
  /// "Match tie-break".  ITF: MT-03, TB-01, NA-01, GM-02
  static func gameState(_ state: MatchState) -> LocalizedStringResource? {
    guard state.status == .inProgress else { return nil }
    if state.isMatchTieBreak { return "status.matchTieBreak" }
    if state.isTieBreak { return "status.tieBreak" }
    if state.isDecidingPoint { return "status.decidingPoint" }
    if state.isDeuce { return "status.deuce" }
    return nil
  }

  /// The point display; "0", never "love".  ITF: GM-01
  static func display(_ points: PointDisplay, locale: Locale) -> String {
    switch points {
    case .zero: "0"
    case .fifteen: "15"
    case .thirty: "30"
    case .forty: "40"
    case .advantage: text("score.points.advantage", locale: locale)
    case .tieBreak(let n): String(n)
    }
  }

  /// As VoiceOver reads it: "advantage" for AD.
  static func spoken(_ points: PointDisplay, locale: Locale) -> String {
    points == .advantage
      ? text("score.points.advantage.spoken", locale: locale) : display(points, locale: locale)
  }

  static func side(_ side: CourtSide) -> LocalizedStringResource {
    switch side {
    case .right: "score.side.right"
    case .left: "score.side.left"
    case .receiversChoice: "score.side.choice"
    }
  }

  static func gamesPhrase(_ count: Int, locale: Locale) -> String {
    text("score.games \(count)", locale: locale)
  }

  static func setsPhrase(_ count: Int, locale: Locale) -> String {
    text("score.sets \(count)", locale: locale)
  }
}
