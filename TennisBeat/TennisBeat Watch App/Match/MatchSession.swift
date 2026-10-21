import Foundation
import Observation
import TennisCore

/// The one live match and the screen route (data-model.md § MatchSession).
///
/// Views read this object and call its commands; they never call the engine themselves.
/// Setup, start, scoring, Undo, the Controls commands and the summary. Spec 003: the workout
/// follows the match through these commands (data-model § WorkoutState, contract §4).
@Observable
final class MatchSession {
  nonisolated enum Route: Hashable, Sendable { case setup, playing, summary }

  private(set) var route: Route = .setup
  private(set) var match: Match?
  private(set) var clock: MatchClock?
  private(set) var isPaused = false
  /// The New match rows, as currently chosen. Stored only when a match starts (Story 1 s5).
  var formatChoice: FormatChoice
  /// The match's workout (spec 003). In memory only (FR-014).
  private(set) var workoutState: WorkoutState = .none
  /// A workout save failed; New match shows the notice once (FR-015, research R5). Not stored.
  private(set) var pendingSaveFailureNotice = false
  /// The latest heart-rate reading of the running workout, for the header (Story 3). In
  /// memory only, and cleared with the match (FR-014). It is kept while the summary is open:
  /// after Undo within 30 s the header shows it again, as Q3's freshness allows (#31 R2-4).
  private(set) var latestHeartRate: HeartRateReading?
  /// The workout's statistics the summary shows (FR-013, research R7): taken when the summary
  /// opens, replaced by the saved workout's after the 10-minute save, dropped on Undo, Done or
  /// a failure (Duration only, Story 4 s3). In memory only (FR-014).
  private(set) var summaryStatistics: WorkoutStatistics?

  @ObservationIgnored let haptics: HapticPlaying
  @ObservationIgnored let announcer: Announcing
  /// The workout behind the match (spec 003).
  @ObservationIgnored let workout: WorkoutService
  /// Drives the 10-minute summary timeout (research R4).
  @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
  /// The current match's workout; events of any other workout are dropped (research R11).
  @ObservationIgnored private var workoutToken: WorkoutToken?
  @ObservationIgnored private var summaryTimeout: Task<Void, Never>?

  /// How long the summary waits before saving the workout by itself (Story 2 s7).
  static let summaryTimeoutDuration: Duration = .seconds(600)
  @ObservationIgnored let now: () -> Date
  /// The language for announcements; read per command, so a language change applies next time.
  @ObservationIgnored let locale: () -> Locale
  @ObservationIgnored private let store: FormatStore
  @ObservationIgnored private let makeFormat: (FormatChoice) -> MatchFormat?
  @ObservationIgnored private let coinToss: () -> Player

  init(
    store: FormatStore, haptics: HapticPlaying, announcer: Announcing,
    workout: WorkoutService, now: @escaping () -> Date,
    makeFormat: @escaping (FormatChoice) -> MatchFormat? = { $0.matchFormat },
    coinToss: @escaping () -> Player = CoinToss.systemToss,
    locale: @escaping () -> Locale = { .current },
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) {
    self.store = store
    self.haptics = haptics
    self.announcer = announcer
    self.workout = workout
    self.now = now
    self.makeFormat = makeFormat
    self.coinToss = coinToss
    self.locale = locale
    self.sleep = sleep
    formatChoice = store.load()
    workout.onEvent = { [weak self] token, event in self?.handle(event, of: token) }
  }

  /// A new toss each time (Story 1 s9, s10).
  func tossCoin() -> Player { coinToss() }

  /// Starts a 0–0 match with the chosen format and first server (Story 1 s8).  ITF: SV-01
  func start(firstServer: Player) {
    guard route == .setup, let format = makeFormat(formatChoice) else { return }
    store.save(formatChoice)
    match = Match(setup: MatchSetup(format: format, firstServer: firstServer))
    let clock = MatchClock(startedAt: now())
    self.clock = clock
    isPaused = false
    latestHeartRate = nil
    summaryStatistics = nil
    route = .playing
    // Permission is read at every start (Story 5 s4, research R3).
    if workout.canStartWorkout {
      workoutState = .running
      workoutToken = workout.start(at: clock.startedAt)
    } else {
      workoutState = .none
      workoutToken = nil
    }
  }

  // MARK: Scoring

  /// Points are added only while playing, not paused, and in progress (Story 2 s3, FR-005).
  var acceptsPoints: Bool {
    route == .playing && !isPaused && match?.state.status == .inProgress
  }

  /// Something other than the setup to undo (Story 4 s3, FR-015). Spec 003: not on the
  /// summary once a workout save has started (FR-007, #28 R6-3).
  var canUndo: Bool {
    guard (match?.events.count ?? 0) > 1 else { return false }
    switch workoutState {
    case .saving, .saved: return route != .summary
    default: return true
    }
  }

  /// At least one point in the event list (FR-018).
  var hasPlayedPoint: Bool {
    match?.events.contains { if case .point = $0 { true } else { false } } ?? false
  }

  /// Server correction, pause and End need a match in progress (Story 4 s9, FR-016).
  private var isInProgress: Bool {
    route == .playing && match?.state.status == .inProgress
  }

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
      summaryOpened()
    }
  }

  /// Removes the last event (Story 4 s2). From the summary it brings the match back at
  /// match point, or before the early end, with the clock running again and the time on
  /// the summary not counted (Story 5 s9). No haptic, even when the state brought back calls
  /// for a change of ends (Story 3 s7); only a status change is announced.
  func undo() {
    haptics.cancelPending()
    guard route == .playing || route == .summary, canUndo, var match else { return }
    let before = match.state
    match.undo()
    self.match = match
    if route == .summary {
      clock?.reopen(at: now())
      isPaused = false
      route = .playing
      cancelSummaryTimeout()
      summaryStatistics = nil
      if case .summary = workoutState {
        workout.resume()
        workoutState = .running
      }
    }
    announce([statusChange(from: before, to: match.state)].compactMap(\.self))
  }

  /// Stops the clock and the tap zones until Resume (Story 4 s5, FR-016). No haptic.
  func pause() {
    haptics.cancelPending()
    guard isInProgress, !isPaused, let match else { return }
    clock?.pause(at: now())
    isPaused = true
    if workoutState == .running {
      workout.pause()
      workoutState = .paused
    }
    announce(
      [statusChange(from: match.state, to: match.state, wasPaused: false)].compactMap(\.self))
  }

  /// Continues the clock and the tap zones (Story 4 s6). No haptic.
  func resume() {
    guard isPaused, let match else { return }
    clock?.resume(at: now())
    isPaused = false
    if workoutState == .paused {
      workout.resume()
      workoutState = .running
    }
    announce([statusChange(from: match.state, to: match.state, wasPaused: true)].compactMap(\.self))
  }

  /// Records a first-server correction to the other player and announces the new server
  /// (Story 4 s9, s10). Works while paused and keeps the pause. No haptic.  ITF: CE-02
  func correctServer() {
    haptics.cancelPending()
    guard isInProgress, var match else { return }
    let before = match.state
    do {
      try match.correctFirstServer(to: match.effectiveFirstServer.other)
    } catch {
      return
    }
    self.match = match
    let server = text(match.state.server == .me ? "player.me" : "player.opponent")
    announce(
      [text("announce.server \(server)"), statusChange(from: before, to: match.state)]
        .compactMap(\.self))
  }

  /// A `-uiTestPoints` step, through the same command as its tap (spec 002 contract §2).
  func play(_ step: LaunchStep) {
    switch step {
    case .point(let player): addPoint(for: player)
    case .undo: undo()
    case .correctServer: correctServer()
    }
  }

  /// Ends the match early after the confirmation (Story 4 s12, s13). With a point played it
  /// records the early end and opens the summary; with none the match is discarded and New
  /// match opens, so a 0-point match is never kept. No haptic.  ITF: MT-08
  func endEarly() {
    haptics.cancelPending()
    guard isInProgress, var match else { return }
    guard hasPlayedPoint else {
      self.match = nil
      clock = nil
      isPaused = false
      route = .setup
      if workoutState == .running || workoutState == .paused {
        workout.discard()  // FR-008
        workoutState = .discarded
      }
      latestHeartRate = nil
      return
    }
    do {
      try match.endEarly()
    } catch {
      return  // rejected: the session, the pause included, stays as it was (#21 R1-1)
    }
    self.match = match
    clock?.stop(at: now())
    isPaused = false
    route = .summary
    summaryOpened()
  }

  /// Leaves the summary for New match with the stored format (Story 5 s10).
  func done() {
    haptics.cancelPending()
    guard route == .summary else { return }
    cancelSummaryTimeout()
    if case .summary(let openedAt) = workoutState { saveWorkout(endingAt: openedAt) }
    match = nil
    clock = nil
    isPaused = false
    formatChoice = store.load()
    latestHeartRate = nil
    summaryStatistics = nil
    route = .setup
  }

  /// Hides the save-failure notice after OK (FR-015).
  func dismissSaveFailureNotice() {
    pendingSaveFailureNotice = false
  }

  /// The scene became active: saves at once if the 10-minute timer missed while the app was
  /// suspended (research R4's safety net).
  func checkSummaryTimeout() {
    guard route == .summary, case .summary(let openedAt) = workoutState,
      now().timeIntervalSince(openedAt)
        >= TimeInterval(Self.summaryTimeoutDuration.components.seconds)
    else { return }
    cancelSummaryTimeout()
    saveWorkout(endingAt: openedAt)
  }

  // MARK: Workout (spec 003)

  /// The summary opened at the winning point or the confirmed End: the workout pauses with
  /// its end date fixed, and the 10-minute timer starts (Story 2 s4, research R2, R4).
  private func summaryOpened() {
    guard let stoppedAt = clock?.stoppedAt else { return }
    switch workoutState {
    case .running: workout.pause()
    case .paused: break  // End confirmed while paused: already paused (#28 R6-6)
    default: return
    }
    workoutState = .summary(openedAt: stoppedAt)
    summaryStatistics = workout.statistics()
    summaryTimeout = Task { [weak self, sleep] in
      do { try await sleep(Self.summaryTimeoutDuration) } catch { return }
      guard !Task.isCancelled, let self, self.route == .summary,
        case .summary(let openedAt) = self.workoutState
      else { return }
      self.summaryTimeout = nil
      self.saveWorkout(endingAt: openedAt)
    }
  }

  private func cancelSummaryTimeout() {
    summaryTimeout?.cancel()
    summaryTimeout = nil
  }

  /// One save per match (FR-009). `Task.immediate` hands the save the current workout before
  /// Done changes the route, so a match started at once can't take its place (research R11).
  private func saveWorkout(endingAt date: Date) {
    workoutState = .saving
    let token = workoutToken
    Task.immediate { [weak self, workout] in
      do {
        let saved = try await workout.save(endingAt: date)
        guard let self, self.workoutToken == token, self.workoutState == .saving else { return }
        self.workoutState = .saved
        // Still on the summary (the 10-minute save): show exactly Health's values (R7).
        if self.route == .summary { self.summaryStatistics = saved.statistics }
      } catch {
        guard let self else { return }
        self.pendingSaveFailureNotice = true  // also after Done and a new match (R5)
        guard self.workoutToken == token, self.workoutState == .saving else { return }
        self.workoutState = .failed  // Undo returns on the summary (R3-2)
        self.summaryStatistics = nil  // Duration only (Story 4 s3)
      }
    }
  }

  /// Workout events change only `workoutState`, never the match, the clock, the route or the
  /// pause (FR-011). Events of an earlier workout are dropped (research R11).
  private func handle(_ event: WorkoutEvent, of token: WorkoutToken) {
    guard token == workoutToken else { return }
    switch event {
    case .heartRate(let reading):
      // Only the running or paused workout's readings count (data-model § WorkoutState).
      if workoutState == .running || workoutState == .paused { latestHeartRate = reading }
    case .failed:
      switch workoutState {
      case .running, .paused, .summary:
        cancelSummaryTimeout()
        workoutState = .failed
        latestHeartRate = nil
        summaryStatistics = nil
        workout.discard()  // ends the failed session, so it can't stay active (#30 R1-1)
      default: break
      }
    case .endedUnexpectedly:
      // Without a workout from now on; what it collected is saved best effort, as in Q6
      // (#28 R6-4, research R3), and a failure shows the notice as any failed save (#30 P2-1).
      let end: Date
      switch workoutState {
      case .running, .paused: end = now()
      case .summary(let openedAt): end = openedAt
      default: return
      }
      cancelSummaryTimeout()
      workoutState = .failed
      latestHeartRate = nil
      summaryStatistics = nil
      Task.immediate { [weak self, workout] in
        do {
          _ = try await workout.save(endingAt: end)
        } catch {
          self?.pendingSaveFailureNotice = true  // also after Done and a new match (R5)
        }
      }
    }
  }

  private func text(_ resource: LocalizedStringResource) -> String {
    ScoreScreenModel.text(resource, locale: locale())
  }

  /// The new status text when it appears or changes (Story 7 s2): the game state, with
  /// "Paused. " before it while paused (R1-3).
  private func statusChange(
    from before: MatchState, to after: MatchState, wasPaused: Bool? = nil
  ) -> String? {
    let old = statusText(before, paused: wasPaused ?? isPaused)
    let new = statusText(after, paused: isPaused)
    return new.isEmpty || new == old ? nil : new
  }

  private func statusText(_ state: MatchState, paused: Bool) -> String {
    let gameState = ScoreScreenModel.gameState(state).map(text) ?? ""
    guard paused else { return gameState }
    return gameState.isEmpty ? text("status.paused") : text("status.paused.state \(gameState)")
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
        haptics: WatchHaptics(), announcer: VoiceOverAnnouncer(),
        workout: FakeWorkoutService(mode: .denied, now: Date.init), now: Date.init)
    }
  }
#endif
