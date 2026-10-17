import Foundation
import SwiftUI
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// User Story 2 s4–s9: what each zone and the status line show (FR-006..FR-008).
@MainActor
struct ScoreScreenModelTests {
  nonisolated static let en = Locale(identifier: "en")
  nonisolated static let pl = Locale(identifier: "pl")
  nonisolated static let uk = Locale(identifier: "uk")
  private let g = MatchScript.games

  private func model(
    _ points: String, format: MatchFormat = PointOutcomeTests.format(),
    firstServer: Player = .me, paused: Bool = false, locale: Locale = Self.en
  ) -> ScoreScreenModel {
    let match = MatchScript.match(format, firstServer: firstServer, points: points)
    return ScoreScreenModel(
      state: match.state, isPaused: paused, locale: locale, gameScoring: format.gameScoring)
  }

  private func dimmed(_ points: String, paused: Bool = false) -> ScoreScreenModel {
    let match = MatchScript.match(PointOutcomeTests.format(), points: points)
    return ScoreScreenModel(state: match.state, isPaused: paused, locale: Self.en, isDimmed: true)
  }

  @Test(
    "US2 s4 points show 0, 15, 30, 40 and AD; never \"love\"",
    arguments: [
      ("", "0", "0"), ("M", "15", "0"), ("MM", "30", "0"), ("MMMO", "40", "15"),
      ("MMMOOOM", "AD", "40"), ("MMMOOOO", "40", "AD"),
    ])  // ITF: GM-01, GM-02
  func pointDisplays(points: String, me: String, opponent: String) {
    let score = model(points)
    #expect(score[.me].points == me)
    #expect(score[.opponent].points == opponent)
  }

  @Test("US2 s4 \"AD\" in every language")  // glossary
  func advantageEverywhere() {
    for locale in [Self.en, Self.pl, Self.uk] {
      #expect(model("MMMOOOM", locale: locale)[.me].points == "AD")
    }
  }

  @Test("US2 s4 tie-break points are numbers")  // ITF: TB-01
  func tieBreakNumbers() {
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let score = model(toSixAll + "MMMMMOOOOOOM" + "O")
    #expect(score[.me].points == "6")
    #expect(score[.opponent].points == "7")
  }

  @Test("US2 s4 games in the current set, and sets won counted from completed sets")
  func gamesAndSets() {
    let score = model(g(6, .opponent) + g(3, .me) + g(1, .opponent))
    #expect(score[.me].games == 3)
    #expect(score[.opponent].games == 1)
    #expect(score[.me].sets == 0)
    #expect(score[.opponent].sets == 1)
  }

  @Test("US2 s5 only the server has the serve mark and a court side")  // ITF: SV-02
  func onlyServerMarked() {
    for (points, server) in [("", Player.me), (g(1, .me), .opponent)] {
      let score = model(points)
      #expect(score[server].isServer)
      #expect(score[server].courtSide != nil)
      #expect(!score[server.other].isServer)
      #expect(score[server.other].courtSide == nil)
    }
  }

  @Test(
    "US2 s6 Right / Left in EN, PL and UK",
    arguments: [(en, "Right", "Left"), (pl, "z prawej", "z lewej"), (uk, "справа", "зліва")])  // ITF: SV-03
  func courtSides(locale: Locale, right: String, left: String) {
    #expect(model("", locale: locale)[.me].courtSide == right)
    #expect(model("M", locale: locale)[.me].courtSide == left)
  }

  @Test("US2 s6 positive control: PL and UK sides differ from EN")
  func sidesAreTranslated() {
    let english = model("")[.me].courtSide
    #expect(model("", locale: Self.pl)[.me].courtSide != english)
    #expect(model("", locale: Self.uk)[.me].courtSide != english)
  }

  @Test("US2 s6 tie-break sides alternate every point")  // ITF: TB-04
  func tieBreakSides() {
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let start = model(toSixAll)
    let server = Player.allCases.first { start[$0].isServer }!
    #expect(start[server].courtSide == "Right")
    let next = model(toSixAll + "M")
    let nextServer = Player.allCases.first { next[$0].isServer }!
    #expect(next[nextServer].courtSide == "Left")
  }

  @Test(
    "US2 s7 the deciding point shows Choice; VoiceOver reads the receiver's choice",
    arguments: [
      (en, "Choice", "Receiver chooses the side"), (pl, "wybór", "Stronę wybiera odbierający"),
      (uk, "на вибір", "Сторону обирає приймаючий"),
    ])  // ITF: NA-02
  func decidingPointChoice(locale: Locale, pill: String, spoken: String) {
    let score = model(
      "MMMOOO", format: PointOutcomeTests.format(.bestOfThree, .six, .noAd), locale: locale)
    #expect(score[.me].courtSide == pill)
    // The summary reads the receiver's choice; the zone says who chooses (#20 R1-3).
    #expect(score.summaryAccessibilityLabel.localizedCaseInsensitiveContains(spoken))
  }

  @Test("US2 s8 the status line shows exactly one game state, empty otherwise")  // ITF: GM-02, NA-01, TB-01, MT-03
  func statusLine() {
    let noAd = PointOutcomeTests.format(.bestOfThree, .six, .noAd)
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    #expect(model("").statusText == "")
    #expect(model("MMMO").statusText == "")
    #expect(model("MMMOOO").statusText == "Deuce")
    #expect(model("MMMOOO", format: noAd).statusText == "Deciding point")
    #expect(model(toSixAll).statusText == "Tie-break")
    let matchTieBreak = PointOutcomeTests.format(matchTieBreak: true)
    // Only "Match tie-break", although a match tie-break is also a tie-break.
    #expect(
      model(g(6, .me) + g(6, .opponent), format: matchTieBreak).statusText == "Match tie-break")
  }

  @Test(
    "US6 s2 L2 the header's lines follow the longest status of the phase, not the point"
  )  // ITF: GM-02, NA-01, TB-01, MT-03
  func layoutStatus() {
    // #31 L2: zone size changes only when the status itself changes, never between ordinary
    // points, so the header is laid out for the phase's longest status.
    let noAd = PointOutcomeTests.format(.bestOfThree, .six, .noAd)
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let matchTieBreak = PointOutcomeTests.format(matchTieBreak: true)
    for points in ["", "MMMO", "MMMOOO", "MMMOOOM"] {
      #expect(model(points).layoutStatusText == "Deuce", "\(points)")
    }
    #expect(model("", format: noAd).layoutStatusText == "Deciding point")
    #expect(model("MMMOOO", format: noAd).layoutStatusText == "Deciding point")
    #expect(model(toSixAll).layoutStatusText == "Tie-break")
    #expect(model(toSixAll + "MMO").layoutStatusText == "Tie-break")
    let toMatchTieBreak = g(6, .me) + g(6, .opponent)
    #expect(model(toMatchTieBreak, format: matchTieBreak).layoutStatusText == "Match tie-break")
    #expect(
      model(toMatchTieBreak, format: matchTieBreak, paused: true).layoutStatusText == "Paused")
    #expect(model("MMMOOO", locale: Self.uk).layoutStatusText == "Рівно")
    #expect(dimmed("MMMOOO").layoutStatusText == "")
  }

  @Test(
    "US6 s2 L2 the drawn status is empty or the phase's layout status, never wider"
  )  // ITF: GM-02, NA-01, TB-01, MT-03
  func statusNeverWiderThanLayout() {
    // #31 R2-3: the header's lines are chosen for layoutStatusText, so a drawn status other
    // than it could make the zones move between points.
    let noAd = PointOutcomeTests.format(.bestOfThree, .six, .noAd)
    let matchTieBreak = PointOutcomeTests.format(matchTieBreak: true)
    let toSixAll = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent)
    let toMatchTieBreak = g(6, .me) + g(6, .opponent)
    let advantageGame = ["", "M", "MM", "MMM", "MMMO", "MMMOO", "MMMOOO", "MMMOOOM", "MMMOOOMO"]
    var models: [ScoreScreenModel] = []
    for locale in [Self.en, Self.pl, Self.uk] {
      for paused in [false, true] {
        for points in advantageGame {
          models.append(model(points, paused: paused, locale: locale))
          models.append(model(points, format: noAd, paused: paused, locale: locale))
        }
        for extra in ["", "M", "MO", "MMOOMMO"] {
          models.append(model(toSixAll + extra, paused: paused, locale: locale))
          models.append(
            model(toMatchTieBreak + extra, format: matchTieBreak, paused: paused, locale: locale))
        }
      }
    }
    for model in models {
      #expect(model.statusText.isEmpty || model.statusText == model.layoutStatusText)
    }
  }

  @Test("US2 s8 the status line in PL and UK", arguments: [(pl, "Równowaga"), (uk, "Рівно")])
  func statusTranslated(locale: Locale, deuce: String) {
    #expect(model("MMMOOO", locale: locale).statusText == deuce)
  }

  @Test("US2 s9 advantage leaves the status line empty")  // ITF: GM-02
  func advantageEmptyStatus() {
    #expect(model("MMMOOOM").statusText == "")
    #expect(model("MMMOOOO").statusText == "")
  }

  @Test("FR-008 paused replaces the game state on screen")
  func pausedOnScreen() {
    #expect(model("MMMOOO", paused: true).statusText == "Paused")
    #expect(model("", paused: true).statusText == "Paused")
  }

  // MARK: Always On (US6, FR-021)

  nonisolated static let dimmedCases: [(Locale, TimeInterval, String)] = [
    (en, 2_579, "42 min"),  // 42:59, rounded down
    (en, 5_040, "84 min"),
    (en, 59, "0 min"),
    (pl, 2_520, "42 min"),
    (uk, 2_520, "42 хв"),
  ]

  @Test(
    "US6 s1 the dimmed time is whole minutes in the system's abbreviated format, rounded down",
    arguments: dimmedCases)
  func dimmedMinutes(locale: Locale, seconds: TimeInterval, expected: String) {
    #expect(ScoreScreenModel.dimmedElapsed(seconds, locale: locale) == expected)
  }

  @Test("US6 s2 Q8 dimmed: no Undo, no serve icon, no court-side pill, no status line")
  func dimmedHides() {
    let deuce = dimmed("MMMOOO")
    #expect(!deuce.showsUndo)
    #expect(deuce.statusText.isEmpty)
    for zone in deuce.zones {
      #expect(!zone.showsServeMark)
      #expect(zone.courtSide == nil)
    }
    // Paused and dimmed: "Paused" is hidden too.
    #expect(dimmed("M", paused: true).statusText.isEmpty)
  }

  @Test("US6 s2 positive control: not dimmed, the server's mark, pill, status and Undo show")
  func notDimmedShows() {
    let deuce = model("MMMOOO")
    #expect(deuce.showsUndo)
    #expect(deuce.statusText == "Deuce")
    #expect(deuce[.me].showsServeMark)
    #expect(deuce[.me].courtSide != nil)
    #expect(!deuce[.opponent].showsServeMark)
  }

  @Test("US6 s2 dimmed keeps the score and the VoiceOver texts")
  func dimmedKeepsScore() {
    let lit = model("MMO")
    let dark = dimmed("MMO")
    #expect(dark[.me].points == lit[.me].points)
    #expect(dark[.opponent].points == lit[.opponent].points)
    #expect(dark.summaryAccessibilityLabel == lit.summaryAccessibilityLabel)
  }

  @Test("R5 the dimmed redraws fall on whole elapsed minutes, after a 90 s pause")
  func elapsedMinuteSchedule() {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var clock = MatchClock(startedAt: start)
    clock.pause(at: start + 30)
    clock.resume(at: start + 120)
    let from = start + 120  // elapsed 0:30
    let entries = Array(
      ElapsedMinuteSchedule(clock: clock).entries(from: from, mode: .lowFrequency).prefix(4))
    #expect(entries.first == from)
    let minutes = entries.dropFirst().map { clock.elapsed(at: $0) }
    for (minute, elapsed) in zip([60.0, 120, 180], minutes) {
      #expect(abs(elapsed - minute) < 0.001)
    }
    // Starting on a whole minute, the next redraw is the following minute.
    let onMinute = Array(
      ElapsedMinuteSchedule(clock: clock).entries(from: start + 150, mode: .lowFrequency)
        .prefix(2))
    #expect(abs(clock.elapsed(at: onMinute[1]) - 120) < 0.001)
  }

  @Test("R5 while paused the dimmed time doesn't change, so there is no later redraw")
  func elapsedMinuteSchedulePaused() {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var clock = MatchClock(startedAt: start)
    clock.pause(at: start + 30)
    let entries = Array(
      ElapsedMinuteSchedule(clock: clock).entries(from: start + 40, mode: .lowFrequency).prefix(3))
    #expect(entries == [start + 40])
  }

  @Test("R5 once the clock has stopped the dimmed time doesn't change, so there is no later redraw")
  func elapsedMinuteScheduleStopped() {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var clock = MatchClock(startedAt: start)
    clock.stop(at: start + 90)
    let entries = Array(
      ElapsedMinuteSchedule(clock: clock).entries(from: start + 100, mode: .lowFrequency).prefix(3))
    #expect(entries == [start + 100])
    // Stopped during a pause: still no later redraw.
    var pausedThenStopped = MatchClock(startedAt: start)
    pausedThenStopped.pause(at: start + 30)
    pausedThenStopped.stop(at: start + 50)
    let stoppedEntries = Array(
      ElapsedMinuteSchedule(clock: pausedThenStopped).entries(
        from: start + 100, mode: .lowFrequency
      ).prefix(3))
    #expect(stoppedEntries == [start + 100])
  }
}
