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
    /// The serve icon: on the server, never in Always On (Q8).
    let showsServeMark: Bool
    /// "Right" / "Left" / "Choice" for the server, nil for the receiver and in Always On (Q8).
    /// ITF: SV-03, TB-04, NA-02
    let courtSide: String?
    let accessibilityLabel: String
    let accessibilityHint: String
  }

  /// Opponent on top, then Me (FR-005).
  let zones: [Zone]
  /// The status line: "Paused", a game state, or empty (FR-008); empty in Always On (Q8).
  let statusText: String
  /// Undo in the header; hidden in Always On (FR-021).
  let showsUndo: Bool
  /// Whether the match takes points now (`MatchSession.acceptsPoints`).
  let acceptsPoints: Bool
  /// "Paused. <state>", "<state>" or empty (R1-3).
  let statusAccessibilityText: String
  /// Read first: the server's score, who serves and the side, then the status (Story 7 s1, s2).
  let summaryAccessibilityLabel: String

  subscript(player: Player) -> Zone {
    zones.first { $0.player == player }!
  }

  /// `isDimmed`: the Always On rendering (Watch 5, FR-021).
  init(
    state: MatchState, isPaused: Bool, locale: Locale, acceptsPoints: Bool = true,
    isDimmed: Bool = false
  ) {
    func text(_ resource: LocalizedStringResource) -> String {
      Self.text(resource, locale: locale)
    }
    func name(_ player: Player) -> String {
      text(player == .me ? "player.me" : "player.opponent")
    }

    let gameState = Self.gameState(state).map(text) ?? ""
    statusText = isDimmed ? "" : isPaused ? text("status.paused") : gameState
    showsUndo = !isDimmed
    self.acceptsPoints = acceptsPoints
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
      // First person for Me, the Opponent named (#20 R1-2); on the deciding point the
      // zone says who chooses the side (#20 R1-3).  ITF: NA-02
      let serving: String? =
        if isServer {
          switch (player, state.courtSide) {
          case (.me, .right): text("score.zone.serving.me.right")
          case (.me, .left): text("score.zone.serving.me.left")
          case (.me, .receiversChoice): text("score.zone.serving.me.choice")
          case (.opponent, .right): text("score.zone.serving.opponent.right")
          case (.opponent, .left): text("score.zone.serving.opponent.left")
          case (.opponent, .receiversChoice): text("score.zone.serving.opponent.choice")
          }
        } else { nil }
      return Zone(
        player: player, label: label, points: Self.display(state.points[player], locale: locale),
        games: games, sets: sets, isServer: isServer, showsServeMark: isServer && !isDimmed,
        courtSide: isServer && !isDimmed ? text(Self.side(state.courtSide)) : nil,
        accessibilityLabel: [sentence, serving].compactMap(\.self).joined(separator: " "),
        accessibilityHint: text("score.zone.hint \(label)"))
    }
  }

  /// In Always On the zones take no taps, even while the match accepts points (Story 6 s3).
  func zonesAcceptTaps(isLuminanceReduced: Bool) -> Bool {
    acceptsPoints && !isLuminanceReduced
  }

  /// The Always On header: whole elapsed minutes in the system's abbreviated format, rounded
  /// down, "42 min" / «42 хв» (Story 6 s1, R1-8, research R5).
  static func dimmedElapsed(_ seconds: TimeInterval, locale: Locale) -> String {
    Duration.seconds(Int(seconds)).formatted(
      .units(allowed: [.minutes], width: .abbreviated, fractionalPart: .hide(rounded: .down))
        .locale(locale))
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
