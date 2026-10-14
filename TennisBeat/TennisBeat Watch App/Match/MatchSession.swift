import Foundation
import Observation
import TennisCore

/// The one live match and the screen route (data-model.md § MatchSession).
///
/// Views read this object and call its commands; they never call the engine themselves.
/// Setup, start, scoring and the header Undo; Controls and the full summary arrive in PR 3–4.
@Observable
final class MatchSession {
  enum Route: Hashable { case setup, playing, summary }

  private(set) var route: Route = .setup
  private(set) var match: Match?
  private(set) var clock: MatchClock?
  private(set) var isPaused = false
  /// The New match rows, as currently chosen. Stored only when a match starts (Story 1 s5).
  var formatChoice: FormatChoice

  @ObservationIgnored let haptics: HapticPlaying
  @ObservationIgnored let announcer: Announcing
  @ObservationIgnored let now: () -> Date
  /// The language for announcements; read per command, so a language change applies next time.
  @ObservationIgnored let locale: () -> Locale
  @ObservationIgnored private let store: FormatStore
  @ObservationIgnored private let makeFormat: (FormatChoice) -> MatchFormat?
  @ObservationIgnored private let coinToss: () -> Player

  init(
    store: FormatStore, haptics: HapticPlaying, announcer: Announcing,
    now: @escaping () -> Date,
    makeFormat: @escaping (FormatChoice) -> MatchFormat? = { $0.matchFormat },
    coinToss: @escaping () -> Player = CoinToss.systemToss,
    locale: @escaping () -> Locale = { .current }
  ) {
    self.store = store
    self.haptics = haptics
    self.announcer = announcer
    self.now = now
    self.makeFormat = makeFormat
    self.coinToss = coinToss
    self.locale = locale
    formatChoice = store.load()
  }

  /// A new toss each time (Story 1 s9, s10).
  func tossCoin() -> Player { coinToss() }

  /// Starts a 0–0 match with the chosen format and first server (Story 1 s8).  ITF: SV-01
  func start(firstServer: Player) {
    guard route == .setup, let format = makeFormat(formatChoice) else { return }
    store.save(formatChoice)
    match = Match(setup: MatchSetup(format: format, firstServer: firstServer))
    clock = MatchClock(startedAt: now())
    isPaused = false
    route = .playing
  }

  // MARK: Scoring

  /// Points are added only while playing, not paused, and in progress (Story 2 s3, FR-005).
  var acceptsPoints: Bool {
    route == .playing && !isPaused && match?.state.status == .inProgress
  }

  /// Something other than the setup to undo (Story 4 s3, FR-015).
  var canUndo: Bool { (match?.events.count ?? 0) > 1 }

  /// Adds one point (Story 2 s2). Haptics and announcements come only from the outcome
  /// of this point (FR-010..FR-012, research R2–R4).
  func addPoint(for player: Player) {
    guard acceptsPoints, var match else { return }
    let before = match.state
    do {
      try match.recordPoint(wonBy: player, at: now())
    } catch {
      return  // rejected (ITF: MT-08): nothing changes, nothing plays
    }
    self.match = match
    let outcome = PointOutcome.evaluate(before: before, after: match.state, winner: player)
    haptics.flushPending()
    haptics.play(outcome)

    var parts: [String] = []
    let winner = text(player == .me ? "player.me" : "player.opponent")
    switch outcome.level {
    case .point: break
    case .game: parts.append(text("announce.game \(winner)"))
    case .set: parts.append(text("announce.set \(winner)"))
    case .match: parts.append(text("announce.match \(winner)"))
    }
    if outcome.changeOfEnds { parts.append(text("announce.changeEnds")) }
    if outcome.level != .match, let status = statusChange(from: before, to: match.state) {
      parts.append(status)
    }
    announce(parts)

    if case .won = match.state.status {
      clock?.stop(at: now())
      route = .summary
    }
  }

  /// Removes the last event (Story 4 s2). No haptic, even when the state brought back
  /// calls for a change of ends (Story 3 s7); only a status change is announced.
  func undo() {
    haptics.cancelPending()
    guard route == .playing, canUndo, var match else { return }
    let before = match.state
    match.undo()
    self.match = match
    announce([statusChange(from: before, to: match.state)].compactMap(\.self))
  }

  /// Leaves the summary for New match with the stored format (Story 5 s10).
  func done() {
    haptics.cancelPending()
    guard route == .summary else { return }
    match = nil
    clock = nil
    isPaused = false
    formatChoice = store.load()
    route = .setup
  }

  private func text(_ resource: LocalizedStringResource) -> String {
    ScoreScreenModel.text(resource, locale: locale())
  }

  /// The new status-line text when it appears or changes (Story 7 s2).
  private func statusChange(from before: MatchState, to after: MatchState) -> String? {
    let old = ScoreScreenModel.gameState(before).map(text) ?? ""
    let new = ScoreScreenModel.gameState(after).map(text) ?? ""
    return new.isEmpty || new == old ? nil : new
  }

  /// One combined announcement per command (research R4).
  private func announce(_ parts: [String]) {
    guard !parts.isEmpty else { return }
    announcer.announce(parts.joined(separator: ". "))
  }
}

#if DEBUG
  extension MatchSession {
    /// A session for SwiftUI previews, with an in-memory store.
    static var preview: MatchSession {
      MatchSession(
        store: FormatStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
        haptics: WatchHaptics(), announcer: VoiceOverAnnouncer(), now: Date.init)
    }
  }
#endif
