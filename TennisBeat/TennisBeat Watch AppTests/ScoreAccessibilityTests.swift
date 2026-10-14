import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// User Story 7 s1, s2, s8 on the score screen: what VoiceOver reads (R2-1).
@MainActor
struct ScoreAccessibilityTests {
  private let g = MatchScript.games

  private func model(
    _ points: String, format: MatchFormat = PointOutcomeTests.format(),
    firstServer: Player = .me, paused: Bool = false, locale: Locale = ScoreScreenModelTests.en
  ) -> ScoreScreenModel {
    let match = MatchScript.match(format, firstServer: firstServer, points: points)
    return ScoreScreenModel(state: match.state, isPaused: paused, locale: locale)
  }

  @Test("US7 s1 the summary reads the server's score first, with separate Me and Opponent strings")  // ITF: GM-01, SV-03
  func summary() {
    #expect(model("MO").summaryAccessibilityLabel == "15–15, I'm serving, from the right")
    #expect(model("MMO").summaryAccessibilityLabel == "30–15, I'm serving, from the left")
    #expect(
      model("MMO", firstServer: .opponent).summaryAccessibilityLabel
        == "15–30, Opponent serving, from the left")
    #expect(
      model("OO", firstServer: .opponent).summaryAccessibilityLabel
        == "30–0, Opponent serving, from the right")
  }

  @Test("US7 s1 AD is read as \"advantage\"")  // ITF: GM-02
  func summaryAdvantage() {
    #expect(
      model("MMMOOOM").summaryAccessibilityLabel == "advantage–40, I'm serving, from the left")
    #expect(
      model("MMMOOOM", locale: ScoreScreenModelTests.uk).summaryAccessibilityLabel
        == "перевага–40, подаю, зліва")
  }

  @Test("US7 s1 the deciding point reads the receiver's choice")  // ITF: NA-02
  func summaryDecidingPoint() {
    let noAd = PointOutcomeTests.format(.bestOfThree, .six, .noAd)
    #expect(
      model("MMMOOO", format: noAd).summaryAccessibilityLabel
        == "40–40, I'm serving, receiver chooses the side. Deciding point")
    #expect(
      model("MMMOOO", format: noAd, firstServer: .opponent).summaryAccessibilityLabel
        == "40–40, Opponent serving, receiver chooses the side. Deciding point")
  }

  @Test("US7 s1 the summary in PL and UK")
  func summaryTranslated() {
    #expect(
      model("MMO", locale: ScoreScreenModelTests.uk).summaryAccessibilityLabel
        == "30–15, подаю, зліва")
    #expect(
      model("MMO", firstServer: .opponent, locale: ScoreScreenModelTests.uk)
        .summaryAccessibilityLabel == "15–30, подає суперник, зліва")
    #expect(
      model("MMO", locale: ScoreScreenModelTests.pl).summaryAccessibilityLabel
        == "30–15, serwuję, z lewej")
    #expect(
      model("MMO", firstServer: .opponent, locale: ScoreScreenModelTests.pl)
        .summaryAccessibilityLabel == "15–30, serwuje przeciwnik, z lewej")
  }

  @Test("US7 s1 each zone reads the player, points, games, sets and serve, with a hint")
  func zoneLabel() {
    // Set 1 won by Me; set 2 at 3–1, Me serving game 5 at 30–0.
    let score = model(g(6, .me) + g(3, .me) + g(1, .opponent) + "MM")
    #expect(score[.me].accessibilityLabel == "Me, 30. 3 games, 1 set. Serving from the right.")
    #expect(score[.me].accessibilityHint == "Add point for Me")
    #expect(score[.opponent].accessibilityLabel == "Opponent, 0. 1 game, 0 sets.")
    #expect(score[.opponent].accessibilityHint == "Add point for Opponent")
  }

  @Test(
    "US7 s1 games and sets use plural forms in PL and UK",
    arguments: [
      (
        ScoreScreenModelTests.pl, [1: "1 gem", 2: "2 gemy", 5: "5 gemów", 22: "22 gemy"],
        [1: "1 set", 2: "2 sety", 5: "5 setów", 22: "22 sety"]
      ),
      (
        ScoreScreenModelTests.uk, [1: "1 гейм", 2: "2 гейми", 5: "5 геймів", 22: "22 гейми"],
        [1: "1 сет", 2: "2 сети", 5: "5 сетів", 22: "22 сети"]
      ),
      (
        ScoreScreenModelTests.en, [1: "1 game", 2: "2 games", 5: "5 games", 22: "22 games"],
        [1: "1 set", 2: "2 sets", 5: "5 sets", 22: "22 sets"]
      ),
    ])
  func plurals(locale: Locale, games: [Int: String], sets: [Int: String]) {
    for (count, text) in games {
      #expect(ScoreScreenModel.gamesPhrase(count, locale: locale) == text)
    }
    for (count, text) in sets {
      #expect(ScoreScreenModel.setsPhrase(count, locale: locale) == text)
    }
  }

  @Test("US7 s8 the server is marked by the serve mark and by words; zones by label and order")
  func notColourOnly() {
    for (locale, phrase) in [
      (ScoreScreenModelTests.en, "I'm serving"), (ScoreScreenModelTests.pl, "serwuję"),
      (ScoreScreenModelTests.uk, "подаю"),
    ] {
      let score = model("", locale: locale)
      #expect(score[.me].isServer)
      #expect(score.summaryAccessibilityLabel.contains(phrase))
    }
    let score = model("")
    #expect(score.zones.map(\.player) == [.opponent, .me])
    #expect(score[.me].label == "Me")
    #expect(score[.opponent].label == "Opponent")
  }

  @Test("US7 s2 the summary ends with the status; paused reads \"Paused\" and the state")  // ITF: GM-02
  func summaryStatus() {
    #expect(
      model("MMMOOO").summaryAccessibilityLabel == "40–40, I'm serving, from the right. Deuce")
    #expect(
      model("MMMOOO", paused: true).summaryAccessibilityLabel
        == "40–40, I'm serving, from the right. Paused. Deuce")
    #expect(
      model("", paused: true).summaryAccessibilityLabel
        == "0–0, I'm serving, from the right. Paused")
    #expect(model("").summaryAccessibilityLabel == "0–0, I'm serving, from the right")
    #expect(model("MMMOOO", paused: true).statusAccessibilityText == "Paused. Deuce")
    #expect(
      model("MMMOOO", paused: true, locale: ScoreScreenModelTests.uk).statusAccessibilityText
        == "Пауза. Рівно")
  }

  @Test(
    "US7 s1 the zone's serve phrase is first person for Me, and names the Opponent (#20 R1-2)",
    arguments: [
      (ScoreScreenModelTests.en, "Serving from the right.", "Serving from the left."),
      (ScoreScreenModelTests.uk, "Подаю, справа.", "Подає суперник, зліва."),
      (ScoreScreenModelTests.pl, "Serwuję, z prawej.", "Serwuje przeciwnik, z lewej."),
    ])  // ITF: SV-03
  func zoneServePhrase(locale: Locale, meRight: String, opponentLeft: String) {
    let me = model("", locale: locale)[.me].accessibilityLabel
    #expect(me.hasSuffix(" " + meRight), "\(me)")
    let opponent = model("O", firstServer: .opponent, locale: locale)[.opponent]
      .accessibilityLabel
    #expect(opponent.hasSuffix(" " + opponentLeft), "\(opponent)")
  }

  @Test(
    "US7 s1 on the deciding point the zone says who chooses the side (#20 R1-3)",
    arguments: [
      (ScoreScreenModelTests.en, "Serving. Opponent chooses the side.",
       "Opponent serving. You choose the side."),
      (ScoreScreenModelTests.uk, "Подаю. Сторону обирає суперник.",
       "Подає суперник. Сторону обираю я."),
      (ScoreScreenModelTests.pl, "Serwuję. Stronę wybiera przeciwnik.",
       "Serwuje przeciwnik. Stronę wybieram ja."),
    ])  // ITF: NA-02
  func zoneDecidingPoint(locale: Locale, meServing: String, opponentServing: String) {
    let noAd = PointOutcomeTests.format(.bestOfThree, .six, .noAd)
    let me = model("MMMOOO", format: noAd, locale: locale)[.me].accessibilityLabel
    #expect(me.hasSuffix(" " + meServing), "\(me)")
    let opponent = model("MMMOOO", format: noAd, firstServer: .opponent, locale: locale)[
      .opponent
    ].accessibilityLabel
    #expect(opponent.hasSuffix(" " + opponentServing), "\(opponent)")
  }
}
