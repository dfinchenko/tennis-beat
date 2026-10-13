import Foundation
import Observation
import TennisCore

/// The one live match and the screen route (data-model.md § MatchSession).
///
/// Views read this object and call its commands; they never call the engine themselves.
/// This PR covers setup and start. Scoring, controls and the summary arrive in PR 2–4.
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
  @ObservationIgnored private let store: FormatStore
  @ObservationIgnored private let makeFormat: (FormatChoice) -> MatchFormat?
  @ObservationIgnored private let coinToss: () -> Player

  init(
    store: FormatStore, haptics: HapticPlaying, announcer: Announcing,
    now: @escaping () -> Date,
    makeFormat: @escaping (FormatChoice) -> MatchFormat? = { $0.matchFormat },
    coinToss: @escaping () -> Player = CoinToss.systemToss
  ) {
    self.store = store
    self.haptics = haptics
    self.announcer = announcer
    self.now = now
    self.makeFormat = makeFormat
    self.coinToss = coinToss
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
