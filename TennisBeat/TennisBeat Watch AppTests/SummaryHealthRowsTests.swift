import Foundation
import HealthKit
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// The summary's heart-rate and energy rows (spec 003 Story 4 s1–s3, s8, FR-013; data-model
/// § SummaryHealthRows, research R7, R13; T047).
struct SummaryHealthRowsTests {
  static let en = Locale(identifier: "en")
  static let pl = Locale(identifier: "pl")
  static let uk = Locale(identifier: "uk")

  static func rows(
    _ average: Int? = 138, _ maximum: Int? = 171, _ energy: Double? = 612, locale: Locale = en
  ) -> SummaryHealthRows {
    SummaryHealthRows(
      statistics: WorkoutStatistics(
        averageHeartRate: average, maximumHeartRate: maximum, activeEnergy: energy),
      locale: locale)
  }

  /// The system's own format, the reference for PL (research R13).
  static func kcal(
    _ value: Double, _ width: Measurement<UnitEnergy>.FormatStyle.UnitWidth, _ locale: Locale
  )
    -> String
  {
    Measurement(value: value, unit: UnitEnergy.kilocalories).formatted(
      .measurement(
        width: width, usage: .asProvided,
        numberFormatStyle: .number.precision(.fractionLength(0))
      ).locale(locale))
  }

  @Test("US4 s1 both rows, in the order heart rate, energy, with their EN texts")
  func bothRows() throws {
    let rows = Self.rows()
    #expect(rows.rows.map(\.kind) == [.heartRate, .energy])
    let heartRate = try #require(rows.heartRate)
    #expect(heartRate.label == "Heart rate avg / max")
    #expect(heartRate.value == "138 / 171")
    let energy = try #require(rows.energy)
    #expect(energy.label == "Active energy")
    #expect(energy.value == "612 kcal")
  }

  @Test("FR-016 the drawn heart-rate values use the system number format (#35 R2-1)")
  func heartRateNumberFormat() {
    // A locale whose digits are not ASCII shows that the values go through the system format.
    let arabic = Locale(identifier: "en@numbers=arab")
    let expected =
      "\(138.formatted(.number.locale(arabic))) / \(171.formatted(.number.locale(arabic)))"
    #expect(expected == "١٣٨ / ١٧١")
    #expect(Self.rows(locale: arabic).heartRate?.value == expected)
    #expect(Self.rows(locale: Self.en).heartRate?.value == "138 / 171")
  }

  @Test("US4 s1 the labels and the energy value in PL and UK")
  func translated() throws {
    let pl = Self.rows(locale: Self.pl)
    #expect(pl.heartRate?.label == "Tętno śr. / maks.")
    #expect(pl.heartRate?.value == "138 / 171")
    #expect(pl.energy?.label == "Aktywna energia")
    #expect(pl.energy?.value == Self.kcal(612, .abbreviated, Self.pl))
    let uk = Self.rows(locale: Self.uk)
    #expect(uk.heartRate?.label == "Пульс сер. / макс.")
    #expect(uk.energy?.label == "Активна енергія")
    #expect(uk.energy?.value == "612 ккал")
    // Positive control: the translations are used, not the English source.
    #expect(pl.energy?.label != Self.rows().energy?.label)
  }

  @Test("US4 s2 a row without its value is hidden")
  func hiddenRows() {
    #expect(Self.rows(nil, nil, 612).rows.map(\.kind) == [.energy])
    #expect(Self.rows(138, nil, 612).heartRate == nil)  // the average alone is no row
    #expect(Self.rows(nil, 171, 612).heartRate == nil)
    #expect(Self.rows(138, 171, nil).rows.map(\.kind) == [.heartRate])
    #expect(Self.rows(nil, nil, nil).rows.isEmpty)
  }

  @Test("US4 s3 no statistics (no workout, or it failed): no rows")
  func noStatistics() {
    #expect(SummaryHealthRows(statistics: nil, locale: Self.en).rows.isEmpty)
    #expect(!Self.rows().rows.isEmpty)  // positive control
  }

  @Test(
    "US4 s8 VoiceOver reads each row in full, with the plural on the maximum",
    arguments: [
      (en, 138, 171, "Heart rate: average 138, maximum 171 beats per minute"),
      (en, 1, 1, "Heart rate: average 1, maximum 1 beat per minute"),
      (pl, 138, 171, "Tętno: średnio 138, maksymalnie 171 uderzeń na minutę"),
      (pl, 138, 172, "Tętno: średnio 138, maksymalnie 172 uderzenia na minutę"),
      (pl, 1, 1, "Tętno: średnio 1, maksymalnie 1 uderzenie na minutę"),
      (uk, 138, 171, "Пульс: середній 138, максимальний 171 удар на хвилину"),
      (uk, 138, 172, "Пульс: середній 138, максимальний 172 удари на хвилину"),
      (uk, 138, 175, "Пульс: середній 138, максимальний 175 ударів на хвилину"),
    ])
  func spokenHeartRate(locale: Locale, average: Int, maximum: Int, expected: String) {
    #expect(Self.rows(average, maximum, locale: locale).heartRate?.accessibilityLabel == expected)
  }

  @Test("US4 s8 VoiceOver reads the energy in full units")
  func spokenEnergy() {
    #expect(Self.rows().energy?.accessibilityLabel == "Active energy: 612 kilocalories")
    #expect(Self.rows(138, 171, 1).energy?.accessibilityLabel == "Active energy: 1 kilocalorie")
    #expect(
      Self.rows(locale: Self.pl).energy?.accessibilityLabel
        == "Aktywna energia: \(Self.kcal(612, .wide, Self.pl))")
    #expect(
      Self.rows(locale: Self.uk).energy?.accessibilityLabel == "Активна енергія: 612 кілокалорій")
    // Positive control: PL is not the English text.
    #expect(
      Self.rows(locale: Self.pl).energy?.accessibilityLabel
        != Self.rows().energy?.accessibilityLabel)
  }

  @Test(
    "Edge: rounding: whole beats per minute from HealthKit, whole kilocalories as the formatter rounds"
  )
  func rounding() {
    let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
    let statistics = HealthKitWorkoutService.statistics(
      averageHeartRate: HKQuantity(unit: beatsPerMinute, doubleValue: 137.6),
      maximumHeartRate: HKQuantity(unit: beatsPerMinute, doubleValue: 170.5),
      activeEnergy: HKQuantity(unit: .kilocalorie(), doubleValue: 611.5))
    let rows = SummaryHealthRows(statistics: statistics, locale: Self.en)
    #expect(rows.heartRate?.value == "138 / 171")  // 170.5 rounds up (`rounded()`)
    #expect(rows.energy?.value == Self.kcal(611.5, .abbreviated, Self.en))
    #expect(rows.energy?.value == "612 kcal")
    #expect(Self.rows(138, 171, 612.4).energy?.value == "612 kcal")
    #expect(
      Self.rows(138, 171, 612.4).energy?.accessibilityLabel == "Active energy: 612 kilocalories")
  }

  @Test("FR-013 the summary model carries the rows after Duration; none without statistics")
  @MainActor
  func inSummaryModel() {
    let start = Date(timeIntervalSinceReferenceDate: 1000)
    var clock = MatchClock(startedAt: start)
    clock.stop(at: start + 600)
    let format = PointOutcomeTests.format(.oneSet, .four)
    let state = MatchScript.match(format, points: MatchScript.games(4, for: .me)).state
    let model = SummaryModel(
      state: state, clock: clock, locale: Self.en,
      statistics: WorkoutStatistics(averageHeartRate: 138, maximumHeartRate: 171, activeEnergy: 612)
    )
    #expect(model.health == Self.rows())
    #expect(SummaryModel(state: state, clock: clock, locale: Self.en).health.rows.isEmpty)
  }
}
