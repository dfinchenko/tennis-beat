import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// User Story 5: the summary's title, set chips, duration and VoiceOver texts (FR-019,
/// data-model.md § SummaryModel).
@MainActor
struct SummaryModelTests {
  private let g = MatchScript.games
  private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

  private func summary(
    _ points: String, format: MatchFormat = PointOutcomeTests.format(),
    endEarly: Bool = false, elapsed: TimeInterval = 0,
    locale: Locale = ScoreScreenModelTests.en
  ) throws -> SummaryModel {
    var match = MatchScript.match(format, points: points)
    if endEarly { try match.endEarly() }
    var clock = MatchClock(startedAt: start)
    clock.stop(at: start + elapsed)
    return SummaryModel(state: match.state, clock: clock, locale: locale)
  }

  private func texts(_ model: SummaryModel) -> [String] { model.chips.map(\.text) }

  // MARK: Title (US5 s2, s3)

  @Test("US5 s2 Win when Me won, Loss when the Opponent won")  // ITF: MT-01
  func winAndLoss() throws {
    #expect(try summary(g(6, .me), format: PointOutcomeTests.format(.oneSet)).title == "Win")
    #expect(try summary(g(6, .opponent), format: PointOutcomeTests.format(.oneSet)).title == "Loss")
  }

  @Test("US5 s3 an early end reads \"Match ended early\", never Win or Loss")  // ITF: MT-08
  func endedEarly() throws {
    #expect(try summary(g(6, .me) + "M", endEarly: true).title == "Match ended early")
    #expect(
      try summary("M", endEarly: true, locale: ScoreScreenModelTests.uk).title == "Матч перервано")
  }

  // MARK: Chips (US5 s4, s5)

  @Test("US5 s4 chips show Me's games first: 6:4, 3:6, and a 7:6 tie-break set (Q11)")  // ITF: ST-03, TB-01
  func setChips() throws {
    let first = g(5, .me) + g(4, .opponent) + g(1, .me)  // 6–4
    let second = g(3, .me) + g(6, .opponent)  // 3–6
    #expect(try texts(summary(first + second + "M", endEarly: true)).prefix(2) == ["6:4", "3:6"])
    let tieBreakSet = g(5, .me) + g(5, .opponent) + g(1, .me) + g(1, .opponent) + "MMMMMMM"
    #expect(try texts(summary(tieBreakSet, format: PointOutcomeTests.format(.oneSet))) == ["7:6"])
  }

  @Test("US5 s4 a match tie-break chip shows its points, 10:7")  // ITF: MT-05
  func matchTieBreakChip() throws {
    let format = PointOutcomeTests.format(matchTieBreak: true)
    let points = g(6, .me) + g(6, .opponent) + String(repeating: "MO", count: 7) + "MMM"
    let model = try summary(points, format: format)
    #expect(texts(model) == ["6:0", "0:6", "10:7"])
    #expect(model.title == "Win")
  }

  @Test("US5 s5 an early end mid-set adds an unfinished chip, e.g. 3:2*")  // ITF: MT-08
  func unfinishedSetChip() throws {
    let points = g(6, .me) + g(3, .me) + g(2, .opponent)
    #expect(try texts(summary(points + "M", endEarly: true)) == ["6:0", "3:2*"])
  }

  @Test("US5 s5 points played in the first game of a set give 0:0*")  // ITF: MT-08
  func unfinishedFirstGame() throws {
    #expect(try texts(summary(g(6, .me) + "M", endEarly: true)) == ["6:0", "0:0*"])
  }

  @Test("US5 s5 right after a completed set, with no point of the next set, no extra chip")  // ITF: MT-08
  func noChipBeforeNextSet() throws {
    #expect(try texts(summary(g(6, .me), endEarly: true)) == ["6:0"])
  }

  @Test("US5 s5 an early end mid-match-tie-break shows its points with *: 7:5*")  // ITF: MT-05, MT-08
  func unfinishedMatchTieBreak() throws {
    let format = PointOutcomeTests.format(matchTieBreak: true)
    let points = g(6, .me) + g(6, .opponent) + String(repeating: "MO", count: 5) + "MM"
    #expect(try texts(summary(points, format: format, endEarly: true)) == ["6:0", "0:6", "7:5*"])
  }

  @Test("US5 s5 at 1–1 in sets, no match tie-break point: no chip; one point: 1:0* or 0:1*")  // ITF: MT-05
  func matchTieBreakNoPoint() throws {
    let format = PointOutcomeTests.format(matchTieBreak: true)
    let toMatchTieBreak = g(6, .me) + g(6, .opponent)
    #expect(try texts(summary(toMatchTieBreak, format: format, endEarly: true)) == ["6:0", "0:6"])
    #expect(
      try texts(summary(toMatchTieBreak + "M", format: format, endEarly: true)) == [
        "6:0", "0:6", "1:0*",
      ])
    #expect(
      try texts(summary(toMatchTieBreak + "O", format: format, endEarly: true)) == [
        "6:0", "0:6", "0:1*",
      ])
  }

  // MARK: Lost sets and VoiceOver (US5 s6, US7 s8)

  @Test("US5 s6 US7 s8 lost sets are marked and read as lost; chips keep set order")
  func lostSets() throws {
    let points = g(6, .me) + g(3, .me) + g(6, .opponent) + g(4, .me) + g(2, .opponent) + "M"
    let model = try summary(points, endEarly: true)
    #expect(model.chips.map(\.isLost) == [false, true, false])
    #expect(
      model.chips.map(\.accessibilityLabel) == [
        "Set 1: 6–0, won", "Set 2: 3–6, lost", "Set 3: 4–2, unfinished",
      ])
  }

  @Test(
    "US5 s6 VoiceOver chips in PL and UK",
    arguments: [
      (ScoreScreenModelTests.pl, "Set 2: 3–6, przegrany", "Set 3: 4–2, niedokończony"),
      (ScoreScreenModelTests.uk, "Сет 2: 3–6, програний", "Сет 3: 4–2, незавершений"),
    ])
  func chipsTranslated(locale: Locale, lost: String, unfinished: String) throws {
    let points = g(6, .me) + g(3, .me) + g(6, .opponent) + g(4, .me) + g(2, .opponent) + "M"
    let labels = try summary(points, endEarly: true, locale: locale).chips.map(\.accessibilityLabel)
    #expect(labels[1] == lost)
    #expect(labels[2] == unfinished)
  }

  @Test(
    "US5 s6 R2-4 a match tie-break chip is read as tie-break points",
    arguments: [
      (ScoreScreenModelTests.en, "Match tie-break: 10–7, won"),
      (ScoreScreenModelTests.pl, "Super tie-break: 10–7, wygrany"),
      (ScoreScreenModelTests.uk, "Матч-тай-брейк: 10–7, виграний"),
    ])  // ITF: MT-05
  func matchTieBreakSpoken(locale: Locale, expected: String) throws {
    let format = PointOutcomeTests.format(matchTieBreak: true)
    let points = g(6, .me) + g(6, .opponent) + String(repeating: "MO", count: 7) + "MMM"
    #expect(
      try summary(points, format: format, locale: locale).chips.last?.accessibilityLabel == expected
    )
  }

  // MARK: Duration (US5 s7, s8)

  @Test("US5 s7 the duration is the stopped clock's elapsed time, as h:mm:ss")
  func duration() throws {
    #expect(
      try summary(g(6, .me), format: PointOutcomeTests.format(.oneSet), elapsed: 5_050).duration
        == "1:24:10")
    #expect(
      try summary(g(6, .me), format: PointOutcomeTests.format(.oneSet), elapsed: 754).duration
        == "0:12:34")
  }

  @Test(
    "US5 s7 #23 R1-3 VoiceOver reads the duration in spoken units",
    arguments: [
      (ScoreScreenModelTests.en, 5_050.0, "1 hour, 24 minutes, 10 seconds"),
      (ScoreScreenModelTests.en, 754.0, "12 minutes, 34 seconds"),
      (ScoreScreenModelTests.pl, 5_050.0, "1 godzina, 24 minuty i 10 sekund"),
      (ScoreScreenModelTests.uk, 5_050.0, "1 година, 24 хвилини і 10 секунд"),
    ])
  func spokenDuration(locale: Locale, elapsed: TimeInterval, expected: String) throws {
    let model = try summary(
      g(6, .me), format: PointOutcomeTests.format(.oneSet), elapsed: elapsed, locale: locale)
    #expect(model.spokenDuration == expected)
  }

  /// Changed by spec 003 (FR-013, Story 4 s3): the model has the Health rows, and without a
  /// workout's statistics they are empty, so the spec 002 summary shows Duration only.
  @Test(
    "US5 s8, spec 003 US4 s3 without workout statistics the summary has no heart-rate or energy row"
  )
  func noHealthFields() throws {
    let model = try summary(g(6, .me), format: PointOutcomeTests.format(.oneSet))
    let fields = Set(Mirror(reflecting: model).children.compactMap(\.label))
    #expect(fields == ["title", "chips", "duration", "spokenDuration", "health"])
    #expect(model.health.rows.isEmpty)
  }
}
