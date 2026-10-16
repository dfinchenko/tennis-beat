import Foundation
import SwiftUI

/// What the score header shows for heart rate (FR-012, Story 3; data-model
/// § HeartRateDisplay, research R6). Pure: built from the workout state, the latest reading,
/// the time and Always On.
nonisolated enum HeartRateDisplay: Hashable, Sendable {
  /// No row: no running workout, or Always On (Story 3 s4, s5).
  case hidden
  /// A reading at most `freshness` old, in beats per minute (Story 3 s1).
  case value(Int)
  /// The heart icon and "--": no reading yet, a stale one, or paused (Story 3 s3, Q3).
  case unavailable

  /// A reading older than this shows "--" (Q3).
  static let freshness: TimeInterval = 30

  init(workoutState: WorkoutState, reading: HeartRateReading?, now: Date, isDimmed: Bool) {
    guard !isDimmed else {
      self = .hidden
      return
    }
    switch workoutState {
    case .running:
      if let reading, now.timeIntervalSince(reading.date) <= Self.freshness {
        self = .value(reading.bpm)
      } else {
        self = .unavailable
      }
    case .paused: self = .unavailable
    default: self = .hidden
    }
  }

  /// The drawn number, or "--"; `nil` without a row.
  var text: String? {
    switch self {
    case .hidden: nil
    case .value(let bpm): String(bpm)
    case .unavailable: "--"
    }
  }

  /// What VoiceOver reads after the elapsed time (Story 3 s6).
  func accessibilityLabel(locale: Locale) -> String? {
    switch self {
    case .hidden: nil
    case .value(let bpm):
      ScoreScreenModel.text("score.heartRate.accessibility \(bpm)", locale: locale)
    case .unavailable:
      ScoreScreenModel.text("score.heartRate.unavailable", locale: locale)
    }
  }

  /// A new reading is shown without animation (Story 3 s2).
  var animation: Animation? { nil }
}
