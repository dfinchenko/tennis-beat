import Foundation
import TennisCore

/// Watch 6, built from the engine state, the clock and the language (data-model.md
/// § SummaryModel, FR-019, Story 5). Views don't format results.
nonisolated struct SummaryModel: Hashable, Sendable {
  struct Chip: Hashable, Sendable {
    /// Me's score first: "6:4", "10:7" for a match tie-break, "3:2*" when unfinished.
    let text: String
    /// Dimmed; the VoiceOver text also says "lost" (Story 5 s6, US7 s8).
    let isLost: Bool
    let accessibilityLabel: String
  }

  /// Win / Loss / Match ended early (Story 5 s2, s3).
  let title: String
  /// One per completed set, in order, plus the unfinished set after an early end.
  let chips: [Chip]
  /// The match time without pauses, h:mm:ss in the current language (Story 5 s7).
  let duration: String
  /// The same time in spoken units for VoiceOver: "1 hour, 24 minutes, 10 seconds"
  /// (#23 R1-3).
  let spokenDuration: String

  init(state: MatchState, clock: MatchClock, locale: Locale) {
    func text(_ resource: LocalizedStringResource) -> String {
      ScoreScreenModel.text(resource, locale: locale)
    }

    title =
      switch state.status {
      case .won(.me): text("summary.win")
      case .won(.opponent): text("summary.loss")
      case .unfinished, .inProgress: text("summary.endedEarly")
      }

    enum Outcome { case won, lost, unfinished }
    func chip(number: Int, me: Int, opponent: Int, isMatchTieBreak: Bool, outcome: Outcome)
      -> Chip
    {
      let label: LocalizedStringResource =
        switch (isMatchTieBreak, outcome) {
        case (false, .won): "summary.chip.set.won \(number) \(me) \(opponent)"
        case (false, .lost): "summary.chip.set.lost \(number) \(me) \(opponent)"
        case (false, .unfinished): "summary.chip.set.unfinished \(number) \(me) \(opponent)"
        case (true, .won): "summary.chip.matchTieBreak.won \(me) \(opponent)"
        case (true, .lost): "summary.chip.matchTieBreak.lost \(me) \(opponent)"
        case (true, .unfinished): "summary.chip.matchTieBreak.unfinished \(me) \(opponent)"
        }
      return Chip(
        text: "\(me):\(opponent)" + (outcome == .unfinished ? "*" : ""),
        isLost: outcome == .lost, accessibilityLabel: text(label))
    }

    var chips: [Chip] = []
    for (index, set) in state.completedSets.enumerated() {
      // A match tie-break shows its points, not its 1–0 games.  ITF: MT-05
      let score = set.isMatchTieBreak ? (set.tieBreak ?? set.games) : set.games
      chips.append(
        chip(
          number: index + 1, me: score.me, opponent: score.opponent,
          isMatchTieBreak: set.isMatchTieBreak, outcome: set.winner == .me ? .won : .lost))
    }
    // The set in play when the match ended early, if a point of it was played (Story 5 s5,
    // R1-2). A match tie-break starts at .tieBreak(0).  ITF: MT-05, MT-08
    if state.status == .unfinished {
      let played =
        state.games.me + state.games.opponent > 0
        || Player.allCases.contains {
          state.points[$0] != .zero && state.points[$0] != .tieBreak(0)
        }
      if played {
        if state.isMatchTieBreak {
          chips.append(
            chip(
              number: chips.count + 1, me: Self.tieBreakPoints(state.points.me),
              opponent: Self.tieBreakPoints(state.points.opponent), isMatchTieBreak: true,
              outcome: .unfinished))
        } else {
          chips.append(
            chip(
              number: chips.count + 1, me: state.games.me, opponent: state.games.opponent,
              isMatchTieBreak: false, outcome: .unfinished))
        }
      }
    }
    self.chips = chips

    let elapsed = Duration.seconds(Int(clock.elapsed(at: clock.stoppedAt ?? clock.startedAt)))
    duration = elapsed.formatted(.time(pattern: .hourMinuteSecond).locale(locale))
    spokenDuration = elapsed.formatted(
      .units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale))
  }

  private static func tieBreakPoints(_ display: PointDisplay) -> Int {
    if case .tieBreak(let points) = display { points } else { 0 }
  }
}
