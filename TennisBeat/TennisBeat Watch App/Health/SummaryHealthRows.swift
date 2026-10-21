import Foundation

/// The summary's heart-rate and energy rows (FR-013, Story 4; data-model § SummaryHealthRows,
/// research R7, R13). A value type with no side effects, built from the summary snapshot and
/// the language; no statistics (no workout, or it failed) gives no rows (Story 4 s3).
nonisolated struct SummaryHealthRows: Hashable, Sendable {
  struct Row: Hashable, Sendable {
    enum Kind: Hashable, Sendable { case heartRate, energy }

    let kind: Kind
    /// "Heart rate avg / max", "Active energy".
    let label: String
    /// "138 / 171", "612 kcal".
    let value: String
    /// The whole row, read by VoiceOver as one element (Story 4 s8).
    let accessibilityLabel: String
  }

  /// Shown when the workout has both an average and a maximum (Story 4 s2).
  let heartRate: Row?
  /// Shown when the workout has an energy value (Story 4 s2).
  let energy: Row?

  /// The rows in their order on the summary, after Duration (contract §3).
  var rows: [Row] { [heartRate, energy].compactMap(\.self) }

  init(statistics: WorkoutStatistics?, locale: Locale) {
    func text(_ resource: LocalizedStringResource) -> String {
      ScoreScreenModel.text(resource, locale: locale)
    }

    if let average = statistics?.averageHeartRate, let maximum = statistics?.maximumHeartRate {
      // The system number format, like every other number on the summary (FR-016, #35 R2-1).
      func number(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
      heartRate = Row(
        kind: .heartRate, label: text("summary.heartRate"),
        value: "\(number(average)) / \(number(maximum))",
        accessibilityLabel: text("summary.heartRate.accessibility \(average) \(maximum)"))
    } else {
      heartRate = nil
    }

    if let kilocalories = statistics?.activeEnergy {
      // Kilocalories whatever the locale (spec Assumptions: no kJ), in whole units (R13).
      let measurement = Measurement(value: kilocalories, unit: UnitEnergy.kilocalories)
      func formatted(_ width: Measurement<UnitEnergy>.FormatStyle.UnitWidth) -> String {
        measurement.formatted(
          .measurement(
            width: width, usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0))
          ).locale(locale))
      }
      energy = Row(
        kind: .energy, label: text("summary.energy"), value: formatted(.abbreviated),
        accessibilityLabel: text("summary.energy.accessibility \(formatted(.wide))"))
    } else {
      energy = nil
    }
  }
}
