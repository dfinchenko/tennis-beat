import Foundation
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
    return ScoreScreenModel(state: match.state, isPaused: paused, locale: locale)
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
    let score = model("MMMOOO", format: PointOutcomeTests.format(.bestOfThree, .six, .noAd), locale: locale)
    #expect(score[.me].courtSide == pill)
    #expect(score[.me].accessibilityLabel.contains(spoken))
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
    #expect(model(g(6, .me) + g(6, .opponent), format: matchTieBreak).statusText == "Match tie-break")
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
}
